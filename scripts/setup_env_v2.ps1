# setup_env_v2.ps1 - consolidated installer with INTERNAL PARALLELISM (Flutter || Android)
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
Log '==== v2 installer start (parallel Flutter + Android) ===='

# ---------- JDK (done in previous run, idempotent re-check) ----------
$jdkHome = Get-ChildItem $JDK_DIR -Directory -ErrorAction SilentlyContinue |
  Where-Object { Test-Path (Join-Path $_.FullName 'bin\java.exe') } | Select-Object -First 1
if (-not $jdkHome) {
  Log '[JDK] downloading JDK 17 ...'
  $zip = Join-Path $TMP 'jdk17.zip'
  Invoke-WebRequest -Uri 'https://mirrors.huaweicloud.com/openjdk/17.0.2/openjdk-17.0.2_windows-x64_bin.zip' -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $JDK_DIR -Force
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
  $jdkHome = Get-ChildItem $JDK_DIR -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'bin\java.exe') } | Select-Object -First 1
}
if (-not $jdkHome) { throw 'JDK missing' }
$env:JAVA_HOME = $jdkHome.FullName
Log ('[JDK] ready: ' + $jdkHome.FullName)

# ---------- JOB A: Android SDK ----------
$jobA = Start-Job -Name 'android' -ScriptBlock {
  $ErrorActionPreference = 'Stop'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $SDK_DIR = 'D:\AI\env\android-sdk'; $TMP = 'D:\AI\env\_downloads'; $ALOG = 'D:\AI\env\job-android.log'
  function L($m) { Add-Content -Path $ALOG -Value (('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m)) }
  New-Item -ItemType Directory -Force -Path $SDK_DIR, $TMP | Out-Null
  $clt = Join-Path $SDK_DIR 'cmdline-tools\latest\bin\sdkmanager.bat'
  if (-not (Test-Path $clt)) {
    L 'downloading cmdline-tools ...'
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
  foreach ($p in @('platform-tools', 'platforms;android-34', 'build-tools;34.0.0')) {
    L ('sdkmanager ' + $p)
    & $clt --sdk_root=$SDK_DIR $p *> (Join-Path $TMP 'sdkmanager-last.txt')
  }
  if (Test-Path (Join-Path $SDK_DIR 'platforms\android-34')) { L 'ANDROID PART DONE' } else { L 'WARN platforms;android-34 missing' }
}

# ---------- JOB B: Flutter SDK ----------
$jobB = Start-Job -Name 'flutter' -ScriptBlock {
  $ErrorActionPreference = 'Stop'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $ROOT = 'D:\AI\env'; $FLUTTER_DIR = Join-Path $ROOT 'flutter'; $TMP = Join-Path $ROOT '_downloads'; $FLOG = 'D:\AI\env\job-flutter.log'
  function L($m) { Add-Content -Path $FLOG -Value (('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m)) }
  New-Item -ItemType Directory -Force -Path $FLUTTER_DIR, $TMP | Out-Null
  if (-not (Test-Path (Join-Path $FLUTTER_DIR 'bin\flutter.bat'))) {
    L 'querying latest stable ...'
    $rel = Invoke-RestMethod -Uri 'https://storage.flutter-io.cn/flutter_infra_release/releases/releases_windows.json'
    $entry = $rel.releases | Where-Object { $_.hash -eq $rel.current_release.stable } | Select-Object -First 1
    $url = 'https://storage.flutter-io.cn/flutter_infra_release/releases/' + $entry.archive
    L ('downloading ' + $url)
    $zip = Join-Path $TMP 'flutter.zip'
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    L 'extracting ...'
    Expand-Archive -Path $zip -DestinationPath $ROOT -Force
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path (Join-Path $FLUTTER_DIR 'bin\flutter.bat'))) {
      $ex = Get-ChildItem $ROOT -Directory | Where-Object { $_.Name -like 'flutter*' -and (Test-Path (Join-Path $_.FullName 'bin\flutter.bat')) } | Select-Object -First 1
      if ($ex -and ($ex.FullName -ne $FLUTTER_DIR)) { Move-Item $ex.FullName $FLUTTER_DIR -Force }
    }
  }
  $env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
  $env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
  $env:PUB_CACHE = Join-Path $ROOT 'pub-cache'
  L 'flutter --version (first run warms Dart SDK) ...'
  & (Join-Path $FLUTTER_DIR 'bin\flutter.bat') --version 2>&1 | ForEach-Object { L ('  ' + $_) }
  & (Join-Path $FLUTTER_DIR 'bin\flutter.bat') config --no-analytics *> $null
  & (Join-Path $FLUTTER_DIR 'bin\dart.bat') --disable-analytics *> $null
  L 'precache --android ...'
  & (Join-Path $FLUTTER_DIR 'bin\flutter.bat') precache --android 2>&1 | ForEach-Object { L ('  ' + $_) }
  Set-Content -Path (Join-Path $ROOT 'FLUTTER_READY') -Value 'ok' -Encoding ascii
  L 'FLUTTER PART DONE'
}

# ---------- wait both ----------
Log 'waiting job:flutter + job:android (see job-flutter.log / job-android.log) ...'
Wait-Job -Job @($jobA, $jobB) | Out-Null
foreach ($j in @($jobA, $jobB)) {
  $out = Receive-Job -Job $j -Keep 2>&1 | Out-String
  if ($out.Trim().Length -gt 0) { Log ('job output [' + $j.Name + ']: ' + $out.Trim()) }
}
if (Test-Path "$ROOT\FLUTTER_READY") { Log '[flutter] OK' } else { Log '[flutter] FAILED - see job-flutter.log' }
if (Test-Path (Join-Path $SDK_DIR 'platforms\android-34')) { Log '[android] OK' } else { Log '[android] FAILED - see job-android.log' }

# ---------- freeze env.local.ps1 ----------
$template = @'
# env.local.ps1 - generated by setup_env_v2.ps1. Usage inside powershell:  . D:\AI\money2.0\scripts\env.local.ps1
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
Log 'DONE v2 installer finished.'
