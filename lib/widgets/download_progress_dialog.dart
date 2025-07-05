import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:xhs_app/models/parse_result.dart';
import 'package:xhs_app/service/file_downloader.dart';
import 'package:xhs_app/utils/http_util.dart';

Future<void> showDownloadProgressDialog({
  required BuildContext context,
  required String url,
  required String savePath,
  required Future<void> Function(File file) onComplete,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return _DownloadProgressDialog(
        url: url,
        savePath: savePath,
        onComplete: onComplete,
      );
    },
  );
}

// 新增批量下载的对话框函数
Future<void> showBatchDownloadProgressDialog({
  required BuildContext context,
  required List<XhsImageInfo> images,
  required List<String> savePaths,
  required Future<void> Function(List<File> files) onComplete,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return _BatchDownloadProgressDialog(
        images: images,
        savePaths: savePaths,
        onComplete: onComplete,
      );
    },
  );
}

class _DownloadProgressDialog extends StatefulWidget {
  final String url;
  final String savePath;
  final Future<void> Function(File file) onComplete;

  const _DownloadProgressDialog({
    required this.url,
    required this.savePath,
    required this.onComplete,
  });

  @override
  _DownloadProgressDialogState createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double progress = 0.0;
  String speed = '0 KB/s';
  bool isDownloading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final file = await FileDownloader.downloadFileConcurrently(
        url: widget.url,
        savePath: widget.savePath,
        onProgress: (prog, spd) {
          if (mounted) {
            setState(() {
              progress = prog;
              speed = spd;
            });
          }
        },
      );

      setState(() {
        isDownloading = false;
      });
      await widget.onComplete(file);
    } catch (e) {
      if (mounted) {
        setState(() {
          isDownloading = false;
          errorMessage = e.toString();
        });
        print(e);
        rethrow;
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('正在下载'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '错误: $errorMessage',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toStringAsFixed(1)}%'),
              Text(speed),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

// 新增批量下载的对话框类
class _BatchDownloadProgressDialog extends StatefulWidget {
  final List<XhsImageInfo> images;
  final List<String> savePaths;
  final Future<void> Function(List<File> files) onComplete;

  const _BatchDownloadProgressDialog({
    required this.images,
    required this.savePaths,
    required this.onComplete,
  });

  @override
  _BatchDownloadProgressDialogState createState() =>
      _BatchDownloadProgressDialogState();
}

class _BatchDownloadProgressDialogState
    extends State<_BatchDownloadProgressDialog> {
  double progress = 0.0;
  String speed = '0 KB/s';
  bool isDownloading = true;
  String? errorMessage;
  int completedCount = 0;

  @override
  void initState() {
    super.initState();
    _startBatchDownload();
  }

  Future<void> _startBatchDownload() async {
    try {
      List<File> downloadedFiles = [];
      for (int i = 0; i < widget.images.length; i++) {
        final file = await FileDownloader.downloadImage(
          image: widget.images[i],
          savePath: widget.savePaths[i],
          onProgress: (prog, spd) {
            if (mounted) {
              setState(() {
                progress = (completedCount + prog) / widget.images.length;
                speed = spd;
              });
            }
          },
        );
        downloadedFiles.add(file);
        if (mounted) {
          setState(() {
            completedCount++;
            progress = completedCount / widget.images.length;
          });
        }
      }

      setState(() {
        isDownloading = false;
      });
      await widget.onComplete(downloadedFiles);
    } catch (e) {
      if (mounted) {
        setState(() {
          isDownloading = false;
          errorMessage = e.toString();
        });
      }
      rethrow;
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('批量下载图片'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '错误: $errorMessage',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}% ($completedCount/${widget.images.length})',
              ),
              Text(speed),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

Future<void> saveToGallery(File tempFile, {required bool isVideo}) async {
  /// 获取存储权限
  Future<bool> getStoragePermission() async {
    late PermissionStatus myPermission;

    /// 读取系统权限
    if (Platform.isIOS) {
      myPermission = await Permission.photosAddOnly.request();
    } else if (Platform.isAndroid) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final info = await deviceInfoPlugin.androidInfo;
      if ((info.version.sdkInt) >= 33) {
        myPermission = await Permission.manageExternalStorage.request();
      } else {
        myPermission = await Permission.storage.request();
      }
    }
    switch (myPermission) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return true;
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.provisional:
        return false;
    }
  }

  bool permissionGranted = await getStoragePermission();

  if (!permissionGranted) {
    throw Exception(
      Platform.isAndroid ? '存储权限被拒绝，请在设置中手动开启' : '相册访问权限被拒绝，请在设置中手动开启',
    );
  }

  // 保存文件到相册
  try {
    if (isVideo) {
    await Gal.putVideo(tempFile.path);
    } else {
      await Gal.putImage(tempFile.path);
    }
  } catch (e) {
    throw Exception('保存到相册失败: $e');
  } finally {
    // 删除临时文件
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }
}
