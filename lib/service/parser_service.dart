import 'dart:convert';

import 'package:xhs_app/models/parse_result.dart';
import 'dart:async';

import 'package:xhs_app/utils/http_util.dart';
import 'package:flutter_js/flutter_js.dart';

class ParserService {
  static final RegExp linkRegex = RegExp(
    r'https?:\/\/www\.xiaohongshu\.com/explore/\S+',
  );
  static final RegExp shareRegex = RegExp(
    r'https?:\/\/www\.xiaohongshu\.com/discovery/item/\S+',
  );
  static final RegExp shortRegex = RegExp(r'https?:\/\/xhslink\.com\/[\/\w]+');
  static final RegExp scriptRegex = RegExp(
    r'<script>window.__INITIAL_STATE__=(.*?)<\/script>',
  );

  static JavascriptRuntime flutterJs = getJavascriptRuntime();

  /// 解析用户输入
  Future<String> _getUrl(String input) async {
    // 处理短链接
    if (shortRegex.hasMatch(input)) {
      return await HttpUtil.expandShortUrl(shortRegex.firstMatch(input)!.group(0)!);
    }
    // 匹配分享链接
    if (shareRegex.hasMatch(input)) {
      return shareRegex.firstMatch(input)!.group(0)!;
    }
    // 匹配普通链接
    else if (linkRegex.hasMatch(input)) {
      return linkRegex.firstMatch(input)!.group(0)!;
    }

    throw ArgumentError('无法解析输入的地址');
  }

  /// 从URL中提取链接ID
  String _extractLinkId(String url) {
    Uri uri = Uri.parse(url);
    List<String> pathSegments = uri.path.split('/');
    return pathSegments.lastWhere(
      (segment) => segment.isNotEmpty,
      orElse: () => '',
    );
  }

  String _extractImageToken(String url) {
    List<String> parts = url.split("/");
    if (parts.length < 6) return ""; // 防止越界
    String token = parts.sublist(5).join("/");
    return token.split("!").first;
  }

  List<XhsImageInfo>? _extractImages(dynamic noteInfo, String imageFormat) {
    if (noteInfo['imageList'] is! List) {
      return null;
    }
    // http2可能导致HTTP/2 stream 1 was not closed cleanly
    return (noteInfo['imageList'] as List)
        .map(
          (image) => XhsImageInfo(
            url: image['urlDefault'],
            rawUrl: "http://sns-na-i6.xhscdn.com/${_extractImageToken(image['urlDefault'])}",
            highQualityUrl: "http://ci.xiaohongshu.com/${_extractImageToken(image['urlDefault'])}?imageView2/format/$imageFormat",
            width: image['width'],
            height: image['height'],
            livePhoto: image['livePhoto'],
          ),
        )
        .toList();
  }

  Future<XhsVideoInfo?> _extractVideo(dynamic noteInfo) async {
    final originVideoKey = noteInfo['video']['consumer']['originVideoKey'];
    final duration = noteInfo['video']['capa']['duration'];
    final url = "https://sns-video-bd.xhscdn.com/$originVideoKey";
    final fileSize = await HttpUtil.getFileSize(url);
    return XhsVideoInfo(
      url: url,
      size: fileSize,
      duration: duration,
    );
  }

  //////////////////////////////////////////////////

  Future<ParseResult> parse(String input, {required String imageFormat}) async {
    final url = await _getUrl(input);
    print(url);
    if (url.isEmpty) {
      throw ArgumentError('无法解析输入的地址');
    }
    final linkId = _extractLinkId(url);
    final html = await HttpUtil.getHtml(url);
    if (!scriptRegex.hasMatch(html)) {
      throw ArgumentError('解析失败');
    }
    final script = scriptRegex.firstMatch(html)!.group(1)!.replaceAll(':undefined', ':null');
    final jsCode = '''
      (function () {
        const obj = $script;
        return JSON.stringify(obj);
      })()
    ''';
    final result = flutterJs.evaluate(jsCode);
    // print(result);
    final json = jsonDecode(result.stringResult);
    final currentNoteId = json['note']['currentNoteId'];
    final noteInfo = json['note']['noteDetailMap'][currentNoteId]['note'];
    final noteId = noteInfo['noteId'];
    final title = noteInfo['title'];
    final desc = noteInfo['desc'];
    final type = noteInfo['type']; // normal: 图文 video: 视频

    final parseResult = ParseResult(noteId: noteId, title: title, desc: desc);
    parseResult.images = _extractImages(noteInfo, imageFormat);
    // await _parseImagesFromApp(noteId);

    if (type == 'video') {
      parseResult.video = await _extractVideo(noteInfo);
    }

    return parseResult;
  }

  Future<List<XhsImageInfo>> _parseImagesFromApp(String noteId) async {
    
    return [];
  }
}
