import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:xhs_app/models/parse_result.dart';
import 'package:xhs_app/service/parser_service.dart';
import 'package:xhs_app/settings_page.dart';
import 'package:xhs_app/settings_provider.dart';
import 'package:xhs_app/utils/common_util.dart';
import 'package:xhs_app/widgets/download_progress_dialog.dart';
import 'package:xhs_app/widgets/parse_result_widget.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: settings.themeMode,
          home: HomePage(),
        );
      },
    );
  }
}

// 主页面，包含底部导航栏
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // 页面列表
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ParserApp(),
      SettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('✨xhs_app✨')),
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
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
  
  bool get isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

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
      textToCopy = _result!.images!.map((img) => img.highQualityUrl.endsWith('raw') ? img.rawUrl : img.highQualityUrl).join("\n");
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
      String downloadDir;
      // 判断是否是桌面端（macOS / Windows）
      if (isDesktop) {
        final selectedDir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '请选择下载保存目录',
          initialDirectory: (await getDownloadsDirectory())?.path,
        );

        if (selectedDir == null) return; // 用户取消了选择
        downloadDir = selectedDir;
      } else {
        // 安卓/iOS 使用临时目录
        final tempDir = await getTemporaryDirectory();
        downloadDir = tempDir.path;
      }

      if (!mounted) return;

      final title = CommonUtil.getAvailableFileName(_result!.title.isEmpty ? _result!.desc : _result!.title) + '_${DateTime.now().millisecondsSinceEpoch}';
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final selectedFormat = settings.imageFormat.code;
      if (_result!.video != null) {
        // 下载视频
        final videoUrl = _result!.video!.url;
        final filePath =
            '$downloadDir/$title.mp4';

        await showDownloadProgressDialog(
          context: context,
          url: videoUrl,
          savePath: filePath,
          onComplete: (file) async {
            print(file);
            if (!isDesktop) {
              await saveToGallery(file, isVideo: true);
            }
            _showSnackBar(context, '视频下载完成');
          },
        );
      } else if (_result!.images != null && _result!.images!.isNotEmpty) {
        // 下载图片，使用统一的进度对话框
        final images = _result!.images!.toList();
        if (singleImageUrl != null) {
          images.removeWhere((element) => element.highQualityUrl != singleImageUrl);
        }
        final filePaths = images.map((ele) =>
            '$downloadDir/${title}_${images.indexOf(ele)}').toList();

        await showBatchDownloadProgressDialog(
          context: context,
          images: images,
          savePaths: filePaths,
          onComplete: (files) async {
            if (!isDesktop){
              for (var file in files) {
                await saveToGallery(file, isVideo: false);
              }
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
      // 获取设置
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final parseResult = await _parserService.parse(
        _inputController.text,
        imageFormat: settings.imageFormat.code, // 使用 code 传递给解析服务
      );
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