$ErrorActionPreference='Continue'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:PUB_CACHE='D:AIenvpub-cache'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:JAVA_HOME='D:AIenvjdkjdk-17.0.2'
$env:ANDROID_HOME='D:AIenvandroid-sdk'
$env:GRADLE_USER_HOME='D:AIenvgradle-home'
$env:Path="D:AIenvlutterin;D:AIenvlutterincachedart-sdkin;$env:Path"
Set-Location 'D:AImoney2.0'
Add-Content 'D:AImoney2.0_build.log' "[$(Get-Date -Format HH:mm:ss)] BUILD START"
flutter build apk --debug 2>&1 | ForEach-Object { Add-Content 'D:AImoney2.0_build.log' $_ }
$exit = $LASTEXITCODE
Add-Content 'D:AImoney2.0_build.log' "[$(Get-Date -Format HH:mm:ss)] BUILD EXIT=$exit"
if ($exit -eq 0 -and (Test-Path 'buildappoutputslutter-apkapp-debug.apk')) {
  Copy-Item 'buildappoutputslutter-apkapp-debug.apk' 'D:AImoney2.0app-debug.apk' -Force
  Add-Content 'D:AImoney2.0_build.log' "[$(Get-Date -Format HH:mm:ss)] APK COPIED"
}
