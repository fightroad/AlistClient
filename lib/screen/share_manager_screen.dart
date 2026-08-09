import 'package:alist/entity/share_entity.dart';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/util/share_utils.dart';
import 'package:alist/widget/alist_scaffold.dart';
import 'package:alist/widget/share_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:sprintf/sprintf.dart';

class ShareManagerScreen extends StatelessWidget {
  const ShareManagerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ShareManagerController());
    return AlistScaffold(
      appbarTitle: Text(Intl.screenName_shareManager.tr),
      body: Obx(() {
        if (controller.loading.value && controller.shares.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return SmartRefresher(
          controller: controller.refreshController,
          enablePullDown: true,
          enablePullUp:
              controller.shares.isNotEmpty && controller.hasMore.value,
          onRefresh: controller.refreshList,
          onLoading: controller.loadMore,
          child: controller.shares.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                    Center(child: Text(Intl.shareManager_empty.tr)),
                  ],
                )
              : ListView.separated(
                  itemCount: controller.shares.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final share = controller.shares[index];
                    return _ShareListTile(
                      share: share,
                      onCopy: () => controller.copyLink(share),
                      onEdit: () => controller.editShare(share),
                      onToggle: () => controller.toggleEnabled(share),
                      onDelete: () => controller.deleteShare(share),
                    );
                  },
                ),
        );
      }),
    );
  }
}

class _ShareListTile extends StatelessWidget {
  const _ShareListTile({
    required this.share,
    required this.onCopy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final ShareEntity share;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final filesText = share.files.isEmpty ? "-" : share.files.join("\n");
    final maxText = share.maxAccessed <= 0 ? "∞" : "${share.maxAccessed}";
    final expiresText = (share.expires == null || share.expires!.isEmpty)
        ? Intl.shareManager_expires_never.tr
        : share.expires!;
    final statusText = share.disabled
        ? Intl.shareManager_status_disabled.tr
        : Intl.shareManager_status_enabled.tr;

    return ListTile(
      title: Text(
        filesText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${share.id} · $statusText"),
            Text(expiresText),
            Text(sprintf(Intl.shareManager_accessed.tr, [
              "${share.accessed}",
              maxText,
            ])),
            if (share.remark.isNotEmpty) Text(share.remark),
          ],
        ),
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case "copy":
              onCopy();
              break;
            case "edit":
              onEdit();
              break;
            case "toggle":
              onToggle();
              break;
            case "delete":
              onDelete();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: "copy",
            child: Text(Intl.shareManager_menu_copyLink.tr),
          ),
          PopupMenuItem(
            value: "edit",
            child: Text(Intl.shareManager_menu_edit.tr),
          ),
          PopupMenuItem(
            value: "toggle",
            child: Text(share.disabled
                ? Intl.shareManager_menu_enable.tr
                : Intl.shareManager_menu_disable.tr),
          ),
          PopupMenuItem(
            value: "delete",
            child: Text(Intl.shareManager_menu_delete.tr),
          ),
        ],
      ),
    );
  }
}

class ShareManagerController extends GetxController {
  final shares = <ShareEntity>[].obs;
  final loading = false.obs;
  final hasMore = false.obs;
  final refreshController = RefreshController(initialRefresh: false);

  int _page = 1;
  static const _perPage = 30;
  int _total = 0;

  @override
  void onInit() {
    super.onInit();
    refreshList();
  }

  @override
  void onClose() {
    refreshController.dispose();
    super.onClose();
  }

  Future<void> refreshList() async {
    loading.value = true;
    _page = 1;
    final resp = await ShareUtils.listShares(page: _page, perPage: _perPage);
    loading.value = false;
    if (resp != null) {
      _total = resp.total;
      shares.assignAll(resp.content ?? []);
      hasMore.value = shares.length < _total;
      refreshController.refreshCompleted();
      if (!hasMore.value) {
        refreshController.loadNoData();
      } else {
        refreshController.resetNoData();
      }
    } else {
      refreshController.refreshFailed();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore.value) {
      refreshController.loadNoData();
      return;
    }
    final next = _page + 1;
    final resp = await ShareUtils.listShares(page: next, perPage: _perPage);
    if (resp != null) {
      _page = next;
      _total = resp.total;
      shares.addAll(resp.content ?? []);
      hasMore.value = shares.length < _total;
      if (hasMore.value) {
        refreshController.loadComplete();
      } else {
        refreshController.loadNoData();
      }
    } else {
      refreshController.loadFailed();
    }
  }

  Future<void> copyLink(ShareEntity share) async {
    await ShareUtils.copyShareLink(share.id, pwd: share.pwd);
    SmartDialog.showToast(Intl.shareResult_tips_copied.tr);
  }

  Future<void> editShare(ShareEntity share) async {
    final updated = await showShareFormDialog(
      files: share.files,
      share: share,
    );
    if (updated != null) {
      final index = shares.indexWhere((e) => e.id == share.id);
      if (index >= 0) {
        shares[index] = updated;
        shares.refresh();
      }
    }
  }

  Future<void> toggleEnabled(ShareEntity share) async {
    final ok = await ShareUtils.setShareEnabled(share.id, share.disabled);
    if (ok) {
      share.disabled = !share.disabled;
      shares.refresh();
      SmartDialog.showToast(Intl.shareManager_tips_updated.tr);
    }
  }

  Future<void> deleteShare(ShareEntity share) async {
    final confirmed = await SmartDialog.show<bool>(
      builder: (context) {
        return AlertDialog(
          title: Text(Intl.shareManager_deleteConfirm_title.tr),
          content: Text(Intl.shareManager_deleteConfirm_content.tr),
          actions: [
            TextButton(
              onPressed: () => SmartDialog.dismiss(result: false),
              child: Text(Intl.shareDialog_btn_cancel.tr),
            ),
            TextButton(
              onPressed: () => SmartDialog.dismiss(result: true),
              child: Text(Intl.shareManager_menu_delete.tr),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final ok = await ShareUtils.deleteShare(share.id);
    if (ok) {
      shares.removeWhere((e) => e.id == share.id);
      SmartDialog.showToast(Intl.shareManager_tips_deleted.tr);
    }
  }
}
