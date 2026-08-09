import 'dart:math';

import 'package:alist/entity/share_entity.dart';
import 'package:alist/net/dio_utils.dart';
import 'package:alist/util/user_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class ShareUtils {
  static const _pwdAlphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  static String randomPassword({int length = 6}) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _pwdAlphabet[random.nextInt(_pwdAlphabet.length)],
    ).join();
  }

  static String buildShareUrl(String shareId) {
    final user = Get.find<UserController>().user.value;
    var serverUrl = user.serverUrl;
    if (!serverUrl.endsWith("/")) {
      serverUrl = "$serverUrl/";
    }
    return "${serverUrl}@s/$shareId";
  }

  static Future<void> copyShareLink(String shareId, {String? pwd}) async {
    final url = buildShareUrl(shareId);
    var text = url;
    if (pwd != null && pwd.isNotEmpty) {
      text = "$url\npwd: $pwd";
    }
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// days == null => permanent (omit expires)
  static String? expiresIsoFromDays(int? days) {
    if (days == null) return null;
    final expires = DateTime.now().toUtc().add(Duration(days: days));
    return expires.toIso8601String();
  }

  static Map<String, dynamic> buildCreateOrUpdateBody({
    required List<String> files,
    String? id,
    String? pwd,
    String? expires,
    int? maxAccessed,
    String? remark,
    bool? disabled,
  }) {
    final body = <String, dynamic>{
      "files": files,
      "pwd": pwd ?? "",
      "remark": remark ?? "",
      "max_accessed": maxAccessed ?? 0,
    };
    if (id != null && id.isNotEmpty) {
      body["id"] = id;
    }
    if (expires != null && expires.isNotEmpty) {
      body["expires"] = expires;
    } else {
      body["expires"] = null;
    }
    if (disabled != null) {
      body["disabled"] = disabled;
    }
    return body;
  }

  static Future<ShareEntity?> createShare({
    required List<String> files,
    String? pwd,
    String? expires,
    int? maxAccessed,
    String? remark,
  }) async {
    ShareEntity? result;
    await DioUtils.instance.requestNetwork<ShareEntity>(
      Method.post,
      "share/create",
      params: buildCreateOrUpdateBody(
        files: files,
        pwd: pwd,
        expires: expires,
        maxAccessed: maxAccessed,
        remark: remark,
      ),
      onSuccess: (data) {
        result = data;
      },
      onError: (code, msg) {
        SmartDialog.showToast(msg);
      },
    );
    return result;
  }

  static Future<ShareEntity?> updateShare({
    required String id,
    required List<String> files,
    String? pwd,
    String? expires,
    int? maxAccessed,
    String? remark,
    bool? disabled,
  }) async {
    ShareEntity? result;
    await DioUtils.instance.requestNetwork<ShareEntity>(
      Method.post,
      "share/update",
      params: buildCreateOrUpdateBody(
        id: id,
        files: files,
        pwd: pwd,
        expires: expires,
        maxAccessed: maxAccessed,
        remark: remark,
        disabled: disabled,
      ),
      onSuccess: (data) {
        result = data;
      },
      onError: (code, msg) {
        SmartDialog.showToast(msg);
      },
    );
    return result;
  }

  static Future<bool> deleteShare(String id) async {
    var ok = false;
    await DioUtils.instance.requestNetwork(
      Method.post,
      "share/delete",
      queryParameters: {"id": id},
      onSuccess: (_) {
        ok = true;
      },
      onError: (code, msg) {
        SmartDialog.showToast(msg);
      },
    );
    return ok;
  }

  static Future<bool> setShareEnabled(String id, bool enabled) async {
    var ok = false;
    await DioUtils.instance.requestNetwork(
      Method.post,
      enabled ? "share/enable" : "share/disable",
      queryParameters: {"id": id},
      onSuccess: (_) {
        ok = true;
      },
      onError: (code, msg) {
        SmartDialog.showToast(msg);
      },
    );
    return ok;
  }

  static Future<ShareListResp?> listShares({
    int page = 1,
    int perPage = 30,
  }) async {
    ShareListResp? result;
    await DioUtils.instance.requestNetwork<ShareListResp>(
      Method.post,
      "share/list",
      params: {"page": page, "per_page": perPage},
      onSuccess: (data) {
        result = data;
      },
      onError: (code, msg) {
        SmartDialog.showToast(msg);
      },
    );
    return result;
  }
}
