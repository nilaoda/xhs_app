import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xhs_app/models/parse_result.dart';
import 'package:xhs_app/service/parser_service.dart';
import 'package:xhs_app/utils/common_util.dart';
import 'package:xhs_app/widgets/download_progress_dialog.dart';
import 'package:xhs_app/widgets/parse_result_widget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate, // Material 组件的本地化
        GlobalWidgetsLocalizations.delegate, // Widgets 的本地化
        GlobalCupertinoLocalizations.delegate, // Cupertino 组件的本地化
      ],
      // 使用默认浅色主题
      theme: ThemeData.light(),
      // 使用默认深色主题
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: Scaffold(
        appBar: AppBar(title: Text('✨小红书搬运工')),
        // 添加这个属性防止键盘遮挡
        resizeToAvoidBottomInset: true,
        // SafeArea避免底部遮挡
        body: SafeArea(child: ParserApp()),
      ),
    );
  }
}

class ParserApp extends StatefulWidget {
  const ParserApp({super.key});

  @override
  ParserAppState createState() => ParserAppState();
}

class ParserAppState extends State<ParserApp> {
  final TextEditingController _inputController = TextEditingController();
  final ParserService _parserService = ParserService();
  ParseResult? _result; // 存储解析结果
  bool _isLoading = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _copyLink() async {
    String textToCopy = "";
    if (_result!.video != null) {
      // 视频
      textToCopy = _result!.video!.url;
    } else if (_result!.images != null && _result!.images!.isNotEmpty) {
      // 图片数组，复制所有图片，一行一个
      textToCopy = _result!.images!.map((img) => img.pngUrl).join("\n");
    }

    if (textToCopy.isEmpty) {
      _showSnackBar(context, "没有可复制的链接");
      return;
    }

    // 复制到剪贴板
    try {
      await Clipboard.setData(ClipboardData(text: textToCopy));
      _showSnackBar(context, "已复制到剪贴板");
    } catch (e) {
      _showSnackBar(context, "复制失败: $e");
    }
  }

  Future<void> _downloadItem({String? singleImageUrl}) async {
    if (_result == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;

      final title = CommonUtil.getAvailableFileName(_result!.title.isEmpty ? _result!.desc : _result!.title) + '_${DateTime.now().millisecondsSinceEpoch}';
      if (singleImageUrl != null) {
        // 下载单张图片
        final filePath =
            '${tempDir.path}/$title.png';

        await showDownloadProgressDialog(
          context: context,
          url: singleImageUrl,
          savePath: filePath,
          onComplete: (file) async {
            await saveToGallery(file, isVideo: false);
            _showSnackBar(context, '图片下载完成');
          },
        );
      } else if (_result!.video != null) {
        // 下载视频
        final videoUrl = _result!.video!.url;
        final filePath =
            '${tempDir.path}/$title.mp4';

        await showDownloadProgressDialog(
          context: context,
          url: videoUrl,
          savePath: filePath,
          onComplete: (file) async {
            print(file);
            await saveToGallery(file, isVideo: true);
            _showSnackBar(context, '视频下载完成');
          },
        );
      } else if (_result!.images != null && _result!.images!.isNotEmpty) {
        // 下载所有图片，使用统一的进度对话框
        final imageUrls = _result!.images!.map((img) => img.pngUrl).toList();
        final filePaths = imageUrls.map((url) =>
            '${tempDir.path}/${title}_${imageUrls.indexOf(url)}.png').toList();

        await showBatchDownloadProgressDialog(
          context: context,
          urls: imageUrls,
          savePaths: filePaths,
          onComplete: (files) async {
            for (var file in files) {
              await saveToGallery(file, isVideo: false);
            }
            _showSnackBar(context, "${files.length} 张图片下载完成");
          },
        );
      }
    } catch (e) {
      _showErrorSnackBar(context, e.toString());
    }
  }

  Future<void> _pasteText() async {
    final clipboardData = await Clipboard.getData('text/plain');
    setState(() {
      _inputController.text = clipboardData?.text ?? '';
    });
  }

  Future<void> _parseItem() async {
    setState(() {
      _isLoading = true;
      _result = null; // 清除旧结果
    });
    try {
      final parseResult = await _parserService.parse(_inputController.text);
      if (!mounted) return;
      setState(() {
        _result = parseResult;
      });
    } catch (e, stack) {
      print("Error: $e, $stack");
      if (!mounted) return;
      _showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearText() {
    setState(() {
      _inputController.text = '';
      _result = null;
    });
  }

  /// 显示提示信息
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// 显示错误提示信息
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 上方输入框
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _inputController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top, // 文本上对齐
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: '输入内容',
                alignLabelWithHint: true,
              ),
            ),
          ),
        ),

        // 中间按钮
        Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(onPressed: _pasteText, child: Text('粘贴')),
              ElevatedButton(onPressed: _clearText, child: Text('清空')),
              ElevatedButton(onPressed: _parseItem, child: Text('解析')),
            ],
          ),
        ),

        // 下方结果展示
        Expanded(
          flex: 13,
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : (_result != null
                      ? ParseResultWidget(
                        result: _result!,
                        onCopy: _copyLink,
                        onDownload: _downloadItem,
                      )
                      : Center(child: Text("请点击 '解析' 按钮"))),
        ),
      ],
    );
  }
}