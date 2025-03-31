import 'package:dio/dio.dart';
import 'dart:io';

import 'package:xhs_app/utils/common_util.dart';

class HttpUtil {
  static final Dio _dio = Dio(
    BaseOptions(connectTimeout: Duration(seconds: 8)),
  );

  static Future<String> expandShortUrl(String shortUrl) async {
    try {
      final response = await _dio.head(
        shortUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => true, // 接受所有状态码
        ),
      );

      if ([301, 302, 303, 307].contains(response.statusCode)) {
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          return await expandShortUrl(location); // 递归展开
        }
      }
      return shortUrl;
    } catch (e) {
      print('Error expanding URL: $e');
      return shortUrl;
    }
  }

  /// 获取网页内容
  static Future<String> getHtml(String url) async {
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load HTML: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load HTML: $e');
    }
  }

  /// 获取文件大小
  static Future<int> getFileSize(String url) async {
    final response = await _dio.head(url);
    if (response.statusCode == 200) {
      final contentLength = response.headers.value('content-length');
      if (contentLength != null) {
        return int.parse(contentLength);
      }
    }
    throw Exception('Failed to get filesize');
  }

  /// 下载文件
  static Future<File> downloadFile({
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
      const int updateIntervalMs = 500; // 更新间隔设为 500ms，避免过于频繁更新

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
        throw Exception('网络请求失败: ${e.message}');
      } else {
        throw Exception('下载失败: $e');
      }
    }
  }
}
