import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/util/download/download_http_client.dart';
import 'package:alist/util/file_utils.dart';
import 'package:alist/widget/alist_scaffold.dart';
import 'package:alist/widget/loading_status_widget.dart';
import 'package:alist/widget/overflow_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TextReaderScreen extends StatelessWidget {
  TextReaderScreen({Key? key}) : super(key: key) {
    if (Get.isRegistered<TextReaderScreenController>()) {
      Get.delete<TextReaderScreenController>(force: true);
    }
    _controller = Get.put(TextReaderScreenController());
  }

  late final TextReaderScreenController _controller;

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
      appbarTitle: OverflowText(text: _controller.item.name),
      body: Obx(
        () => LoadingStatusWidget(
          loading: _controller.loading.value,
          errorMsg: _controller.errMsg.value,
          retryCallback: _controller.load,
          child: SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                _controller.content.value,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TextReaderScreenController extends GetxController {
  static const _maxBytes = 5 * 1024 * 1024;

  final TextReaderItem item = Get.arguments["textReaderItem"];
  final loading = true.obs;
  final errMsg = "".obs;
  final content = "".obs;
  final _httpClient = DownloadHttpClient();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    errMsg.value = "";
    try {
      final localPath = item.localPath;
      if (localPath != null && localPath.isNotEmpty) {
        final file = File(localPath);
        if (await file.exists()) {
          final length = await file.length();
          if (length > _maxBytes) {
            errMsg.value = Intl.textReaderScreen_tips_tooLarge.tr;
            return;
          }
          content.value = await file.readAsString();
          return;
        }
      }

      final url = await FileUtils.makeFileLink(item.remotePath, item.sign);
      if (url == null) {
        errMsg.value = Intl.tips_makeFileLink_failed.tr;
        return;
      }

      final headers = FileUtils.downloadHeadersFor(item.provider);

      final response = await _httpClient.get(
        url,
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        errMsg.value = "HTTP ${response.statusCode}";
        await response.drain();
        return;
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > _maxBytes) {
          errMsg.value = Intl.textReaderScreen_tips_tooLarge.tr;
          await response.drain();
          return;
        }
      }
      content.value = utf8.decode(builder.takeBytes(), allowMalformed: true);
    } catch (e) {
      errMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }
}

class TextReaderItem {
  final String name;
  final String remotePath;
  final String? sign;
  final String? provider;
  final String? localPath;

  TextReaderItem({
    required this.name,
    required this.remotePath,
    this.sign,
    this.provider,
    this.localPath,
  });
}
