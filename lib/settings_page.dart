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
              SwitchListTile(
                title: Text('深色模式'),
                value: settings.themeMode == ThemeMode.dark,
                onChanged: (value) {
                  settings.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              SizedBox(height: 20),
              Text(
                '解析设置',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ListTile(
                title: Text('高清图片格式'),
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
                subtitle: Text('20250705'),
              ),
            ],
          ),
        );
      },
    );
  }
}