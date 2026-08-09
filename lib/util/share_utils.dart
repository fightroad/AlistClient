import 'dart:math';

import 'package:alist/entity/share_entity.dart';
import 'package:alist/l10n/intl_keys.dart';
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
    final buffer = StringBuffer()
      ..writeln("${Intl.shareCopy_link.tr}$url");
    if (pwd != null && pwd.isNotEmpty) {
      buffer.write("${Intl.shareCopy_password.tr}$pwd");
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trimRight()));
  }

  /// days == null => permanent (omit expires)
  static String? expiresIsoFromDays(int? days) {
    if (days == null) return null;
    final expires = DateTime.now().toUtc().add(Duration(days: days));
    // Dart omits timezone for UTC; OpenList expects RFC3339 with Z.
    final iso = expires.toIso8601String();
    return iso.endsWith("Z") ? iso : "${iso}Z";
  }

  static Map<String, dynamic> buildCreateOrUpdateBody({
    required List<String> files,
    String? id,
    String? pwd,
    String? expires,
    int? maxAccessed,
    String? remark,
    bool? disabled,
    int? accessed,
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
    if (accessed != null) {
      body["accessed"] = accessed;
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
    int? accessed,
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
        accessed: accessed,
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
