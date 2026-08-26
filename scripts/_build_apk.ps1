$ErrorActionPreference='Continue'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:PUB_CACHE='D:\AI\env\pub-cache'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:JAVA_HOME='D:\AI\env\jdk\jdk-17.0.2'
$env:ANDROID_HOME='D:\AI\env\android-sdk'
$env:GRADLE_USER_HOME='D:\AI\env\gradle-home'
$env:SQLITE3_FROM_ASSETS='true'
$env:Path="D:\AI\env\flutter\bin;D:\AI\env\flutter\bin\cache\dart-sdk\bin;" + $env:Path
Set-Location 'D:\AI\money2.0'
$log='D:\AI\money2.0\_build3.log'
if(Test-Path $log){Remove-Item $log}
Add-Content $log "[$(Get-Date -Format HH:mm:ss)] PUB GET"
& flutter pub get 2>&1 | ForEach-Object { Add-Content $log $_ }
Add-Content $log "[$(Get-Date -Format HH:mm:ss)] BUILD"
& flutter build apk --debug 2>&1 | ForEach-Object { Add-Content $log $_ }
$e=$LASTEXITCODE
Add-Content $log "[$(Get-Date -Format HH:mm:ss)] EXIT=$e"
if($e -eq 0 -and (Test-Path 'build\app\outputs\flutter-apk\app-debug.apk')){
  Copy-Item 'build\app\outputs\flutter-apk\app-debug.apk' 'D:\AI\money2.0\旅途助手-debug.apk' -Force
  Add-Content $log "[$(Get-Date -Format HH:mm:ss)] APK COPIED"
}