import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                '主题设置',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ListTile(
                title: const Text('主题模式'),
                trailing: DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('跟随系统'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('浅色模式'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('深色模式'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.setThemeMode(value);
                    }
                  },
                ),
              ),
              SizedBox(height: 20),
              Text(
                '解析设置',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ListTile(
                title: Text('下载图片格式'),
                trailing: DropdownButton<ImageFormat>(
                  value: settings.imageFormat,
                  items: ImageFormat.values
                      .map((format) => DropdownMenuItem(
                            value: format,
                            child: Text(format.label), // 显示 label
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      settings.setImageFormat(value);
                    }
                  },
                ),
              ),
              SizedBox(height: 20),
              Text(
                '关于',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ListTile(
                title: Text('应用版本'),
                subtitle: Text('20250705 v2'),
              ),
            ],
          ),
        );
      },
    );
  }
}