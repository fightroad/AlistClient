import 'dart:async';
import 'dart:io';

import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/util/download/download_manager.dart';
import 'package:alist/util/download/download_task.dart';
import 'package:alist/util/download/download_task_status.dart';
import 'package:alist/util/file_type.dart';
import 'package:alist/util/file_utils.dart';
import 'package:alist/widget/alist_scaffold.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class FileReaderScreen extends StatelessWidget {
  FileReaderScreen({Key? key}) : super(key: key);
  final FileReaderItem _fileReaderItem = Get.arguments["fileReaderItem"];

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
      appbarTitle: Text(_fileReaderItem.name),
      body: _FileReaderContainer(fileReaderItem: _fileReaderItem),
    );
  }
}

class _FileReaderContainer extends StatefulWidget {
  const _FileReaderContainer({Key? key, required this.fileReaderItem})
      : super(key: key);
  final FileReaderItem fileReaderItem;

  @override
  State<_FileReaderContainer> createState() => _FileReaderContainerState();
}

class _FileReaderContainerState extends State<_FileReaderContainer> {
  String? _localPath;
  int _downloadProgress = 0;
  String? failedMessage;
  DownloadTask? _downloadTask;
  late StreamSubscription _downloadProgressSubscription;
  late StreamSubscription _downloadStatusChangeSubscription;

  bool get _isDownloading => _localPath == null && failedMessage == null;

  @override
  void initState() {
    super.initState();
    _download(widget.fileReaderItem);
    _downloadProgressSubscription =
        DownloadManager.instance.listenDownloadProgressChange((task) {
      if (task == _downloadTask) {
        setState(() {
          if (task.contentLength != null && task.contentLength! > 0) {
            _downloadProgress =
                (task.downloaded / task.contentLength! * 100).round().clamp(0, 99);
          } else if (task.downloaded > 0) {
            // Unknown total size (common after Aliyun 302): keep spinner text
            // without a fake 0%.
            _downloadProgress = -1;
          }
        });
      }
    });
    _downloadStatusChangeSubscription =
        DownloadManager.instance.listenDownloadStatusChange((task) {
      if (task == _downloadTask) {
        if (task.status == DownloadTaskStatus.failed) {
          setState(() {
            failedMessage =
                task.failedReason ?? Intl.fileReaderScreen_downloadFailed.tr;
            _localPath = "";
          });
          SmartDialog.showToast(
              task.failedReason ?? Intl.fileReaderScreen_downloadFailed.tr);
        } else if (task.status == DownloadTaskStatus.finished) {
          _onDownloadFinish(widget.fileReaderItem.fileType);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isDownloading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_downloadProgress < 0
                  ? Intl.fileReaderScreen_downloading.tr
                  : "$_downloadProgress%"),
            ] else ...[
              if (failedMessage != null) ...[
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  failedMessage!,
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  Intl.fileReaderScreen_downloadedHint.tr,
                  textAlign: TextAlign.center,
                ),
              ],
              if (_localPath != null && _localPath!.isNotEmpty) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _openFile(_localPath),
                  child: Text(
                    widget.fileReaderItem.fileType == FileType.apk &&
                            Platform.isAndroid
                        ? Intl.fileReaderScreen_install.tr
                        : Intl.fileReaderScreen_openAgain.tr,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _downloadTask?.cancel();
    _downloadProgressSubscription.cancel();
    _downloadStatusChangeSubscription.cancel();
    super.dispose();
  }

  void _download(FileReaderItem item) async {
    final fileType = widget.fileReaderItem.fileType;
    final requestHeaders = <String, dynamic>{};
    var limitFrequency = 0;
    if (FileUtils.isBaiduNetdisk(item.provider)) {
      requestHeaders["User-Agent"] = "pan.baidu.com";
    } else if (FileUtils.needsDownloadRateLimit(item.provider)) {
      // 阿里云盘下载请求频率限制为 1s/次
      limitFrequency = 1;
    }

    // Already downloaded (e.g. from download manager).
    if (item.localPath != null &&
        item.localPath!.isNotEmpty &&
        File(item.localPath!).existsSync()) {
      setState(() {
        _downloadProgress = 100;
        _localPath = item.localPath;
      });
      if (!(fileType == FileType.apk && Platform.isAndroid)) {
        _openFile(item.localPath);
      }
      return;
    }

    _downloadTask = await DownloadManager.instance.download(
      name: item.name,
      remotePath: item.remotePath,
      sign: item.sign ?? "",
      thumb: item.thumb,
      requestHeaders: requestHeaders,
      limitFrequency: limitFrequency,
    );
    if (_downloadTask == null) {
      setState(() {
        failedMessage = Intl.fileReaderScreen_downloadFailed.tr;
        _localPath = "";
      });
      SmartDialog.showToast(Intl.fileReaderScreen_downloadFailed.tr);
      return;
    }
    if (_downloadTask?.status == DownloadTaskStatus.finished) {
      _onDownloadFinish(fileType);
    }
  }

  void _onDownloadFinish(FileType? fileType) {
    LogUtil.d("_onDownloadFinish");
    final path = _downloadTask?.record.localPath;
    setState(() {
      _downloadProgress = 100;
      _localPath = path;
      failedMessage = null;
    });
    if (!(fileType == FileType.apk && Platform.isAndroid)) {
      _openFile(path);
    }
  }

  Future<void> _openFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      setState(() {
        failedMessage = Intl.fileReaderScreen_openFailed_notFound.tr;
        _localPath = "";
      });
      return;
    }
    if (!File(filePath).existsSync()) {
      setState(() {
        failedMessage = Intl.fileReaderScreen_openFailed_notFound.tr;
      });
      return;
    }

    final fileType = widget.fileReaderItem.fileType;
    if (fileType == FileType.apk &&
        Platform.isAndroid &&
        !await Permission.requestInstallPackages.isGranted) {
      _showInstallPermissionDialog();
      return;
    }

    final openFileType = _mimeForFileType(fileType);
    try {
      final value = await OpenFile.open(filePath, type: openFileType);
      if (!mounted) return;
      setState(() {
        _downloadProgress = 100;
        _localPath = filePath;
        if (value.type == ResultType.done) {
          failedMessage = null;
        } else {
          failedMessage = _messageForOpenResult(value);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadProgress = 100;
        _localPath = filePath;
        failedMessage = Intl.fileReaderScreen_openFailed_generic.tr;
      });
      LogUtil.e(e);
    }
  }

  String? _mimeForFileType(FileType? fileType) {
    switch (fileType) {
      case FileType.txt:
      case FileType.code:
        return "text/plain";
      case FileType.pdf:
        return "application/pdf";
      case FileType.apk:
        return "application/vnd.android.package-archive";
      case FileType.word:
        return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
      case FileType.excel:
        return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
      case FileType.ppt:
        return "application/vnd.openxmlformats-officedocument.presentationml.presentation";
      default:
        // Let the system infer from extension (.doc/.xls/.zip, etc.).
        return null;
    }
  }

  String _messageForOpenResult(OpenResult value) {
    switch (value.type) {
      case ResultType.noAppToOpen:
        return Intl.fileReaderScreen_openFailed_noApp.tr;
      case ResultType.permissionDenied:
        return Intl.fileReaderScreen_openFailed_permission.tr;
      case ResultType.fileNotFound:
        return Intl.fileReaderScreen_openFailed_notFound.tr;
      case ResultType.error:
      default:
        final msg = value.message.trim();
        if (msg.isEmpty || msg.toLowerCase() == "error") {
          return Intl.fileReaderScreen_openFailed_generic.tr;
        }
        // Prefer localized no-app hint when message looks like that case.
        final lower = msg.toLowerCase();
        if (lower.contains("no app") ||
            lower.contains("cannot be opened") ||
            lower.contains("没有") ||
            lower.contains("无法")) {
          return Intl.fileReaderScreen_openFailed_noApp.tr;
        }
        return msg;
    }
  }

  // just for android.
  void _showInstallPermissionDialog() {
    SmartDialog.show(builder: (context) {
      return AlertDialog(
        title: Text(Intl.installPermissionDialog_title.tr),
        content: Text(Intl.installPermissionDialog_content.tr),
        actions: [
          TextButton(
              onPressed: () {
                SmartDialog.dismiss();
              },
              child: Text(Intl.installPermissionDialog_btn_cancel.tr)),
          TextButton(
              onPressed: () {
                SmartDialog.dismiss();
                Permission.requestInstallPackages.request().then((value) {
                  if (value.isGranted) {
                    _openFile(_localPath);
                  } else {
                    SmartDialog.showToast(
                        Intl.installPermissionDialog_denied.tr);
                  }
                });
              },
              child: Text(Intl.installPermissionDialog_btn_ok.tr)),
        ],
      );
    });
  }
}

class FileReaderItem {
  final String name;
  String? localPath;
  final String remotePath;
  final String? sign;
  final String? provider;
  final String? thumb;
  final FileType? fileType;

  FileReaderItem({
    required this.name,
    this.localPath,
    required this.remotePath,
    this.sign,
    this.provider,
    this.thumb,
    required this.fileType,
  });
}
