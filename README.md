# xhs_app

含有大量AI生成代码的软件工具. iOS需要自签名, 安卓可以装apk.

## 💡 参考项目
https://github.com/JoeanAmier/XHS-Downloader


<!--

release模式编译

flutter devices
flutter run --release -d 00008140-001A00560A0B001C

打包iOS
flutter build ios --release --no-codesign && mkdir -p build/app/Payload && cp -r "build/ios/iphoneos/Runner.app" build/app/Payload && cd build/app && ditto -c -k --sequesterRsrc --keepParent Payload MyApp.ipa && cd .. && open app && cd ..

打包Android
flutter build apk --release --split-per-abi

打包macOS
flutter build macos --release && cd build/macos/Build/Products/Release && ditto -c -k --sequesterRsrc --keepParent xhs_app.app xhs_app.zip && open . && cd ../../../../../

打包Windows（虚拟机中powershell操作，为防止污染代码，重新拉取项目）
pushd C:\Softwares\flutter_temp
Expand-Archive –Path "W:\Windows\flutter_windows_3.32.5-stable.zip" -Destination "."
$env:PATH="C:\Softwares\flutter_temp\flutter\bin;"+$env:PATH
$env:PUB_CACHE="C:\Softwares\flutter_temp\flutter_plugins_cache"
git clone https://github.com/nilaoda/xhs_app
cd xhs_app
flutter build windows --release
Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "xhs_app.zip" -Force
-->