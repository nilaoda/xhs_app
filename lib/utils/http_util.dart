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
  static Future<String> getHtml(String url, {Map<String, dynamic>? headers}) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(headers: headers),
      );
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
}
