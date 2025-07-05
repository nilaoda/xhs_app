import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImageFormat {
  final String label;
  final String code;

  const ImageFormat({required this.label, required this.code});

  // 定义支持的图片格式
  static const ImageFormat original = ImageFormat(label: '原始', code: 'raw');
  static const ImageFormat jpg = ImageFormat(label: 'JPG', code: 'jpg');
  static const ImageFormat png = ImageFormat(label: 'PNG', code: 'png');

  // 所有格式列表
  static const List<ImageFormat> values = [original, jpg, png];

  // 用于 shared_preferences 存储和比较
  @override
  bool operator ==(Object other) =>
      other is ImageFormat && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ImageFormat _imageFormat = ImageFormat.original;

  ThemeMode get themeMode => _themeMode;
  ImageFormat get imageFormat => _imageFormat;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.system.index];
    final formatCode = prefs.getString('imageFormat') ?? 'original';
    _imageFormat = ImageFormat.values.firstWhere(
      (format) => format.code == formatCode,
      orElse: () => ImageFormat.original,
    );
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', themeMode.index);
    notifyListeners();
  }

  Future<void> setImageFormat(ImageFormat imageFormat) async {
    _imageFormat = imageFormat;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('imageFormat', imageFormat.code);
    notifyListeners();
  }
}