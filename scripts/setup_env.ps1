# setup_env.ps1 - travel-assistant v2 toolchain installer (idempotent, China mirrors, D:\AI\env only)
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup_env.ps1
# Uninstall: delete D:\AI\env folder. This script does NOT touch system PATH/registry.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ROOT        = 'D:\AI\env'
$JDK_DIR     = Join-Path $ROOT 'jdk'
$SDK_DIR     = Join-Path $ROOT 'android-sdk'
$FLUTTER_DIR = Join-Path $ROOT 'flutter'
$TMP         = Join-Path $ROOT '_downloads'
$LOG         = Join-Path $ROOT 'setup.log'
New-Item -ItemType Directory -Force -Path $JDK_DIR, $SDK_DIR, $FLUTTER_DIR, $TMP | Out-Null

function Log($m) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
  Write-Host $line
  Add-Content -Path $LOG -Value $line
}

Log '==== toolchain install start (target root D:\AI\env) ===='

# ---------- 1) JDK 17 (huaweicloud zip -> adoptium api fallback) ----------
$jdkHome = Get-ChildItem $JDK_DIR -Directory -ErrorAction SilentlyContinue |
  Where-Object { Test-Path (Join-Path $_.FullName 'bin\java.exe') } | Select-Object -First 1
if (-not $jdkHome) {
  Log '[1/4] downloading JDK 17 ...'
  $zip = Join-Path $TMP 'jdk17.zip'
  $urls = @(
    'https://mirrors.huaweicloud.com/openjdk/17.0.2/openjdk-17.0.2_windows-x64_bin.zip',
    'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk'
  )
  $ok = $false
  foreach ($u in $urls) {
    try {
      Log ('  try ' + $u)
      Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing
      if ((Get-Item $zip).Length -gt 100MB) { $ok = $true; break }
    } catch { Log ('  fail: ' + $_.Exception.Message) }
  }
  if (-not $ok) { throw 'JDK 17 download failed from all sources' }
  Log '  extracting JDK ...'
  Expand-Archive -Path $zip -DestinationPath $JDK_DIR -Force
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
  $jdkHome = Get-ChildItem $JDK_DIR -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'bin\java.exe') } | Select-Object -First 1
}
if (-not $jdkHome) { throw 'java.exe not found after extraction' }
$env:JAVA_HOME = $jdkHome.FullName
Log ('[1/4] JDK ready: ' + $jdkHome.FullName)

# ---------- 2) Android SDK (dl.google.com, verified reachable in v1 project) ----------
$clt = Join-Path $SDK_DIR 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path $clt)) {
  Log '[2/4] downloading Android cmdline-tools ...'
  $zip = Join-Path $TMP 'clt.zip'
  Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath (Join-Path $SDK_DIR 'clt-tmp') -Force
  New-Item -ItemType Directory -Force -Path (Join-Path $SDK_DIR 'cmdline-tools') | Out-Null
  Move-Item (Join-Path $SDK_DIR 'clt-tmp\cmdline-tools') (Join-Path $SDK_DIR 'cmdline-tools\latest') -Force
  Remove-Item (Join-Path $SDK_DIR 'clt-tmp') -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path (Join-Path $SDK_DIR 'licenses') | Out-Null
Set-Content (Join-Path $SDK_DIR 'licenses\android-sdk-license') '24333f8a63b6825ea9c5514f83c2829b004d1fee' -Encoding ascii
Set-Content (Join-Path $SDK_DIR 'licenses\android-sdk-preview-license') '84831b9409646a918e30573bab4c9c91346d8abd' -Encoding ascii
$env:ANDROID_HOME = $SDK_DIR
Log '[2/4] sdkmanager installing platform-tools / platforms;android-34 / build-tools;34.0.0 ...'
foreach ($p in @('platform-tools', 'platforms;android-34', 'build-tools;34.0.0')) {
  Log ('  sdkmanager ' + $p)
  & $clt --sdk_root=$SDK_DIR $p *> (Join-Path $TMP 'sdkmanager-last.txt')
}
if (-not (Test-Path (Join-Path $SDK_DIR 'platforms\android-34'))) { Log '  WARN platforms;android-34 missing, see _downloads\sdkmanager-last.txt' }
Log '[2/4] Android SDK components done'

# ---------- 3) Flutter SDK (storage.flutter-io.cn latest stable) ----------
if (-not (Test-Path (Join-Path $FLUTTER_DIR 'bin\flutter.bat'))) {
  Log '[3/4] querying latest Flutter stable ...'
  $rel = Invoke-RestMethod -Uri 'https://storage.flutter-io.cn/flutter_infra_release/releases/releases_windows.json'
  $entry = $rel.releases | Where-Object { $_.hash -eq $rel.current_release.stable } | Select-Object -First 1
  $url = 'https://storage.flutter-io.cn/flutter_infra_release/releases/' + $entry.archive
  Log ('  downloading ' + $url + ' (~1GB, please wait)')
  $zip = Join-Path $TMP 'flutter.zip'
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  Log '  extracting Flutter ...'
  Expand-Archive -Path $zip -DestinationPath $ROOT -Force
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
  if (-not (Test-Path (Join-Path $FLUTTER_DIR 'bin\flutter.bat'))) {
    $extracted = Get-ChildItem $ROOT -Directory |
      Where-Object { $_.Name -like 'flutter*' -and (Test-Path (Join-Path $_.FullName 'bin\flutter.bat')) } |
      Select-Object -First 1
    if ($extracted -and ($extracted.FullName -ne $FLUTTER_DIR)) {
      Move-Item $extracted.FullName $FLUTTER_DIR -Force
    }
  }
}
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PUB_CACHE = Join-Path $ROOT 'pub-cache'
Log '[3/4] flutter --version (first run fetches Dart SDK) ...'
& (Join-Path $FLUTTER_DIR 'bin\flutter.bat') --version 2>&1 | ForEach-Object { Log ('  ' + $_) }
& (Join-Path $FLUTTER_DIR 'bin\flutter.bat') config --no-analytics *> $null
& (Join-Path $FLUTTER_DIR 'bin\dart.bat') --disable-analytics *> $null

# ---------- 4) freeze env.local.ps1 (session-level, single-quoted here-string + placeholders) ----------
Log '[4/4] generating scripts/env.local.ps1 ...'
$template = @'
# env.local.ps1 - generated by setup_env.ps1. Usage inside powershell:  . D:\AI\money2.0\scripts\env.local.ps1
$env:JAVA_HOME = '__JDK__'
$env:ANDROID_HOME = '__SDK__'
$env:FLUTTER_ROOT = '__FLUTTER__'
$env:GRADLE_USER_HOME = 'D:\AI\env\gradle-home'
$env:PUB_CACHE = 'D:\AI\env\pub-cache'
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:FLUTTER_ROOT\bin;$env:FLUTTER_ROOT\bin\cache\dart-sdk\bin;" + $env:Path
'@
$local = $template.Replace('__JDK__', $jdkHome.FullName).Replace('__SDK__', $SDK_DIR).Replace('__FLUTTER__', $FLUTTER_DIR)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Content -Path (Join-Path $scriptDir 'env.local.ps1') -Value $local -Encoding ascii

Log 'DONE toolchain ready at D:\AI\env. To uninstall just delete that folder.'
