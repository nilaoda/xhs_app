import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:xhs_app/models/chunk.dart';
import 'package:xhs_app/models/parse_result.dart';
import 'package:xhs_app/utils/common_util.dart';

class FileDownloader {
  static final _dio = Dio()
    ..options.headers['User-Agent'] =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36'
    ..options.connectTimeout = Duration(seconds: 30) // 连接超时
    ..options.receiveTimeout = Duration(seconds: 60); // 接收超时
  static final updateIntervalMs = 500; // 更新间隔设为 500ms，避免过于频繁更新


  // 获取图片文件扩展名
  static Future<String> _getImageExtension(String url) async {
    try {
      print(url);
      final response = await http.get(Uri.parse(url));
      final server = response.headers['server'];
      // server: tencent-cos才代表能获取到真实的content-type
      if (!server!.startsWith('tencent')) {
        await Future.delayed(Duration(milliseconds: 300));
        return await _getImageExtension(url);
      }
      final contentType = response.headers['content-type'];
      if (contentType == null) return 'png'; // 默认回退到 png
      switch (contentType) {
        case 'image/jpeg':
          return '.jpg';
        case 'image/png':
          return '.png';
        case 'image/heif':
          return '.heic';
        case 'image/webp':
          return '.webp';
        default:
          return '.png'; // 默认回退
      }
    } catch (e) {
      print('获取图片扩展名失败: $e');
      return '.png'; // 出错时回退到 png
    }
  }

  static Future<File> downloadImage({
    required XhsImageInfo image,
    required String savePath,
    Function(double progress, String speed)? onProgress,
    CancelToken? cancelToken,
    int concurrency = 4,
  }) async {
    // 图片需要获取真实的后缀
    final extension = await _getImageExtension(image.highQualityUrl);
    final toDownloadUrl = image.highQualityUrl.endsWith('raw') ? image.rawUrl : image.highQualityUrl;
    return _downloadFile(url: toDownloadUrl, savePath: savePath + extension, onProgress: onProgress);
  }

  static Future<File> downloadFileConcurrently({
    required String url,
    required String savePath,
    Function(double progress, String speed)? onProgress,
    CancelToken? cancelToken,
    int concurrency = 4,
  }) async {
    var tempFilePaths = [];
    try {
      // 检查服务器是否支持分块下载
      final fileSizeResponse = await _dio.head(url);
      final acceptRanges = fileSizeResponse.headers.value(HttpHeaders.acceptRangesHeader);
      if (acceptRanges == null || !acceptRanges.contains('bytes')) {
        print('服务器不支持分块下载');
        return _downloadFile(url: url, savePath: savePath, onProgress: onProgress);
      }

      final totalSize = int.parse(
          fileSizeResponse.headers.value(HttpHeaders.contentLengthHeader) ?? '0');
      if (totalSize == 0) {
        throw Exception('无法获取文件大小');
      }

      // 分块处理
      final chunks = <Chunk>[];
      final chunkSize = (totalSize / concurrency).ceil();
      for (var i = 0; i < concurrency; i++) {
        final start = i * chunkSize;
        final end = i == concurrency - 1 ? totalSize - 1 : start + chunkSize - 1;
        chunks.add(Chunk(start, end, i));
      }

      // 创建临时文件路径
      final tempDir = Directory.systemTemp;
      tempFilePaths = chunks.map((chunk) {
        return '${tempDir.path}/${savePath.split('/').last}.part${chunk.index}';
      }).toList();

      // 进度跟踪
      final chunkProgress = {for (var chunk in chunks) chunk.index: 0};
      int totalReceived = 0;
      DateTime? lastUpdateTime;
      int lastTotalReceived = 0;

      // 创建取消令牌
      final cancelTokens = List.generate(concurrency, (_) => CancelToken());

      // 处理取消操作
      cancelToken?.whenCancel.then((_) {
        for (var token in cancelTokens) {
          token.cancel('Cancelled');
        }
      });

      // 创建下载任务
      final downloadTasks = chunks.asMap().entries.map((entry) async {
        final chunk = entry.value;
        final tempPath = tempFilePaths[entry.key];
        final chunkCancelToken = cancelTokens[entry.key];

        await _downloadChunk(
          url,
          tempPath,
          chunk.start,
          chunk.end,
          chunkCancelToken,
          (received) {
            chunkProgress[chunk.index] = received;
            totalReceived = chunkProgress.values.reduce((a, b) => a + b);

            final now = DateTime.now();
            if (lastUpdateTime != null) {
              final timeDiff = now.difference(lastUpdateTime!).inMilliseconds;
              if (timeDiff >= updateIntervalMs) {
                final speedBytes = totalReceived - lastTotalReceived;
                final speed = speedBytes / (timeDiff / 1000);
                final progress = totalReceived / totalSize;

                onProgress?.call(progress, CommonUtil.formatSpeed(speed));

                lastTotalReceived = totalReceived;
                lastUpdateTime = now;
              }
            } else {
              lastUpdateTime = now;
              lastTotalReceived = totalReceived;
            }
          },
        );
      }).toList();

      await Future.wait(downloadTasks);

      // 合并临时文件
      final file = File(savePath);
      final sink = file.openWrite(mode: FileMode.write);
      for (var tempPath in tempFilePaths) {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await sink.addStream(tempFile.openRead());
          await tempFile.delete();
        }
      }
      await sink.close();

      return file;
    } catch (e, stack) {
      print(e.toString());
      print(stack);
      // 清理临时文件
      for (var tempPath in tempFilePaths) {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
      if (e is DioException) {
        throw Exception('网络请求失败: ${e.message}');
      } else {
        throw Exception('下载失败: $e');
      }
    }
  }

  static Future<void> _downloadChunk(
    String url,
    String tempPath,
    int start,
    int end,
    CancelToken cancelToken,
    Function(int received) onProgress,
  ) async {
    final response = await _dio.get(
      url,
      options: Options(
        headers: {'Range': 'bytes=$start-$end'},
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) => onProgress(received),
    );

    if (response.statusCode != 206) {
      throw Exception('分块下载失败，状态码: ${response.statusCode}');
    }

    final file = File(tempPath);
    await file.writeAsBytes(response.data, flush: true);
  }

  /// 下载文件
  static Future<File> _downloadFile({
    required String url,
    required String savePath,
    Function(double progress, String speed)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      // 计算下载速度的变量
      DateTime? lastUpdateTime;
      int lastBytes = 0;
      int totalReceivedBytes = 0;

      final response = await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress:
            onProgress != null
                ? (received, total) {
                  totalReceivedBytes = received;
                  double progress = total > 0 ? received / total : -1;

                  final currentTime = DateTime.now();
                  String speed = '0 KB/s';

                  if (lastUpdateTime == null) {
                    // 第一次调用，仅初始化
                    lastUpdateTime = currentTime;
                    lastBytes = received;
                  } else {
                    final timeDiffMs =
                        currentTime.difference(lastUpdateTime!).inMilliseconds;
                    if (timeDiffMs >= updateIntervalMs) {
                      // 达到更新间隔时计算速度
                      final bytesDiff = received - lastBytes;
                      final speedBytesPerSec =
                          (bytesDiff / (timeDiffMs / 1000));
                      speed = CommonUtil.formatSpeed(speedBytesPerSec);

                      // 更新基准值
                      lastUpdateTime = currentTime;
                      lastBytes = received;
                    } else {
                      // 未达到更新间隔，使用上一次的速度
                      return; // 避免频繁回调
                    }
                  }

                  onProgress(progress, speed);
                }
                : null,
      );

      // 检查状态码，接受 200 和 206
      if (response.statusCode == 200 || response.statusCode == 206) {
        final file = File(savePath);
        if (await file.exists()) {
          return file;
        } else {
          throw Exception('文件下载成功但未找到: $savePath');
        }
      } else {
        throw Exception('下载失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('网络请求失败: ${e.error}');
      } else {
        throw Exception('下载失败: $e');
      }
    }
  }
}