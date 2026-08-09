import 'package:alist/entity/share_entity.dart';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/util/share_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

enum _ExpireOption { never, d1, d7, d30 }

class ShareFormDialog extends StatefulWidget {
  const ShareFormDialog({
    Key? key,
    required this.files,
    this.share,
  }) : super(key: key);

  final List<String> files;
  final ShareEntity? share;

  bool get isEdit => share != null;

  @override
  State<ShareFormDialog> createState() => _ShareFormDialogState();
}

class _ShareFormDialogState extends State<ShareFormDialog> {
  late final TextEditingController _pwdController;
  late final TextEditingController _maxAccessedController;
  late final TextEditingController _remarkController;
  late _ExpireOption _expireOption;
  late _ExpireOption _initialExpireOption;
  late bool _disabled;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final share = widget.share;
    _pwdController = TextEditingController(text: share?.pwd ?? "");
    _maxAccessedController = TextEditingController(
      text: share == null ? "0" : "${share.maxAccessed}",
    );
    _remarkController = TextEditingController(text: share?.remark ?? "");
    _disabled = share?.disabled ?? false;
    _expireOption = _inferExpireOption(share?.expires);
    _initialExpireOption = _expireOption;
  }

  _ExpireOption _inferExpireOption(String? expires) {
    if (expires == null || expires.isEmpty) {
      return _ExpireOption.never;
    }
    final dt = DateTime.tryParse(expires);
    if (dt == null) return _ExpireOption.never;
    final days = dt.toUtc().difference(DateTime.now().toUtc()).inDays;
    if (days <= 1) return _ExpireOption.d1;
    if (days <= 7) return _ExpireOption.d7;
    return _ExpireOption.d30;
  }

  int? _daysForOption(_ExpireOption option) {
    switch (option) {
      case _ExpireOption.never:
        return null;
      case _ExpireOption.d1:
        return 1;
      case _ExpireOption.d7:
        return 7;
      case _ExpireOption.d30:
        return 30;
    }
  }

  /// Keep original expiry when editing unless the chip selection changed.
  String? _resolveExpires() {
    if (widget.isEdit && _expireOption == _initialExpireOption) {
      final original = widget.share?.expires;
      if (original == null || original.isEmpty) {
        return null;
      }
      return original;
    }
    return ShareUtils.expiresIsoFromDays(_daysForOption(_expireOption));
  }

  @override
  void dispose() {
    _pwdController.dispose();
    _maxAccessedController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final maxAccessed = int.tryParse(_maxAccessedController.text.trim()) ?? 0;
    final expires = _resolveExpires();
    try {
      if (widget.isEdit) {
        final updated = await ShareUtils.updateShare(
          id: widget.share!.id,
          files: widget.files,
          pwd: _pwdController.text.trim(),
          expires: expires,
          maxAccessed: maxAccessed,
          remark: _remarkController.text.trim(),
          disabled: _disabled,
        );
        if (updated != null) {
          SmartDialog.dismiss(result: updated);
          SmartDialog.showToast(Intl.shareManager_tips_updated.tr);
        }
      } else {
        final created = await ShareUtils.createShare(
          files: widget.files,
          pwd: _pwdController.text.trim(),
          expires: expires,
          maxAccessed: maxAccessed,
          remark: _remarkController.text.trim(),
        );
        if (created != null) {
          SmartDialog.dismiss(result: created);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit
          ? Intl.shareDialog_title_edit.tr
          : Intl.shareDialog_title_create.tr),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pwdController,
              decoration: InputDecoration(
                labelText: Intl.shareDialog_label_password.tr,
                suffixIcon: IconButton(
                  tooltip: Intl.shareDialog_btn_randomPassword.tr,
                  onPressed: () {
                    _pwdController.text = ShareUtils.randomPassword();
                    _pwdController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _pwdController.text.length),
                    );
                  },
                  icon: const Icon(Icons.casino_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(Intl.shareDialog_label_expires.tr),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                _expireChip(_ExpireOption.never, Intl.shareDialog_expires_never.tr),
                _expireChip(_ExpireOption.d1, Intl.shareDialog_expires_1d.tr),
                _expireChip(_ExpireOption.d7, Intl.shareDialog_expires_7d.tr),
                _expireChip(_ExpireOption.d30, Intl.shareDialog_expires_30d.tr),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxAccessedController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: Intl.shareDialog_label_maxAccessed.tr,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarkController,
              decoration: InputDecoration(
                labelText: Intl.shareDialog_label_remark.tr,
              ),
            ),
            if (widget.isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(Intl.shareDialog_label_disabled.tr),
                value: _disabled,
                onChanged: (v) => setState(() => _disabled = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => SmartDialog.dismiss(),
          child: Text(Intl.shareDialog_btn_cancel.tr),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: Text(widget.isEdit
              ? Intl.shareDialog_btn_save.tr
              : Intl.shareDialog_btn_create.tr),
        ),
      ],
    );
  }

  Widget _expireChip(_ExpireOption option, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _expireOption == option,
      onSelected: (_) => setState(() => _expireOption = option),
    );
  }
}

Future<ShareEntity?> showShareFormDialog({
  required List<String> files,
  ShareEntity? share,
}) async {
  return SmartDialog.show<ShareEntity>(
    builder: (_) => ShareFormDialog(files: files, share: share),
  );
}

Future<void> createShareAndShowResult(List<String> files) async {
  final created = await showShareFormDialog(files: files);
  if (created != null) {
    await showShareResultDialog(created);
  }
}

Future<void> showShareResultDialog(ShareEntity share) async {
  final url = ShareUtils.buildShareUrl(share.id);
  await SmartDialog.show(
    builder: (context) {
      return AlertDialog(
        title: Text(Intl.shareResult_title.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Intl.shareResult_link.tr),
            const SizedBox(height: 4),
            SelectableText(url),
            if (share.pwd.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(Intl.shareResult_password.tr),
              const SizedBox(height: 4),
              SelectableText(share.pwd),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => SmartDialog.dismiss(),
            child: Text(Intl.shareResult_btn_close.tr),
          ),
          TextButton(
            onPressed: () async {
              await ShareUtils.copyShareLink(share.id, pwd: share.pwd);
              SmartDialog.showToast(Intl.shareResult_tips_copied.tr);
            },
            child: Text(Intl.shareResult_btn_copy.tr),
          ),
        ],
      );
    },
  );
}
