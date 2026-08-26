# env.local.ps1 - finalized by captain after prewarm verification (flutter cache complete)
$env:JAVA_HOME = 'D:\AI\env\jdk\jdk-17.0.2'
$env:ANDROID_HOME = 'D:\AI\env\android-sdk'
$env:FLUTTER_ROOT = 'D:\AI\env\flutter'
$env:GRADLE_USER_HOME = 'D:\AI\env\gradle-home'
$env:PUB_CACHE = 'D:\AI\env\pub-cache'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:FLUTTER_ROOT\bin;$env:FLUTTER_ROOT\bin\cache\dart-sdk\bin;" + $env:Path
