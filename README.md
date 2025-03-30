# xhs_app

含有大量AI生成代码的软件工具. iOS需要自签名, 安卓可以装apk.

## 📑 功能
下载图片和视频

## 📸 截图
![img](./assets/screen.jpg)

## 💡 参考项目
https://github.com/JoeanAmier/XHS-Downloader


<!--

release模式编译

flutter devices
flutter run --release -d 00008140-001A00560A0B001C

打包
flutter build ios --release --no-codesign && mkdir -p build/app/Payload && cp -r "build/ios/iphoneos/Runner.app" build/app/Payload && cd build/app && zip -r -m MyApp.ipa Payload && cd .. && open app && cd ..

安卓
flutter build apk --release --split-per-abi

-->