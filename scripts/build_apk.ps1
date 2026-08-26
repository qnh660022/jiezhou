# ============================================================
# build_apk.ps1 - One-click DEBUG APK build for Travel Assistant v2.
# Idempotent: safe to re-run on any machine, any number of times.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_apk.ps1
# Prerequisite:
#   scripts\setup_env.ps1 must have completed once
#   (it generates scripts/env.local.ps1 and D:\AI\env toolchain).
# Steps:
#   0) dot-source env.local.ps1 (JDK / Android SDK / Flutter / mirrors)
#   1) gradle-wrapper.properties -> Tencent mirror (keep generated version)
#   2) settings.gradle(.kts) -> Aliyun maven repos on TOP of repository lists,
#      keeping google()/mavenCentral() as fallback
#   3) flutter pub get
#   4) dart run build_runner build --delete-conflicting-outputs
#   5) flutter analyze   (gate: 0 errors)
#   6) flutter test      (gate: all green)
#   7) flutter build apk --debug
# ============================================================
param(
  [string]$ProjectRoot = 'D:\AI\money2.0'
)

$ErrorActionPreference = 'Stop'

function Step([string]$Message) {
  Write-Host ('==> ' + $Message) -ForegroundColor Cyan
}

function CheckExit([string]$Name) {
  if ($LASTEXITCODE -ne 0) {
    Write-Host ('[X] ' + $Name + ' failed, aborting build.') -ForegroundColor Red
    exit 1
  }
}

# ---------- 0) Load toolchain environment ----------
$envScript = Join-Path $ProjectRoot 'scripts\env.local.ps1'
if (-not (Test-Path $envScript)) {
  Write-Host '[X] scripts/env.local.ps1 not found. Run scripts/setup_env.ps1 first.' -ForegroundColor Red
  exit 1
}
Step 'Loading toolchain environment (scripts/env.local.ps1)'
. $envScript
Set-Location $ProjectRoot

# ---------- 1) gradle-wrapper.properties -> Tencent mirror (keep version) ----------
Step 'Checking gradle wrapper distribution mirror (Tencent, idempotent)'
$wrapper = Join-Path $ProjectRoot 'android\gradle\wrapper\gradle-wrapper.properties'
if (Test-Path $wrapper) {
  $content = Get-Content $wrapper -Raw
  if (($content -notmatch 'mirrors\.cloud\.tencent\.com') -and
      ($content -match 'gradle-([0-9][0-9A-Za-z.\-]*\.zip)')) {
    $distFile = 'gradle-' + $Matches[1]
    $pattern = 'distributionUrl=.*'
    $replacement = 'distributionUrl=https\://mirrors.cloud.tencent.com/gradle/' + $distFile
    $updated = [regex]::Replace($content, $pattern, $replacement)
    Set-Content -Path $wrapper -Value $updated -NoNewline -Encoding ascii
    Write-Host ('    Switched to Tencent mirror: ' + $distFile)
  }
  else {
    Write-Host '    Already on mirror source, or no distributionUrl found. Skipped.'
  }
}
else {
  Write-Host '[!] android/ not generated yet (run flutter create first). Skip wrapper step.' -ForegroundColor Yellow
}

# ---------- 2b) project-level build.gradle(.kts) allprojects.repositories -> Aliyun on top ----------
Step('Checking project build.gradle repositories (Aliyun on top, idempotent)')
$projGradle = $null
foreach ($candidate in @('android\build.gradle.kts', 'android\build.gradle')) {
  $p = Join-Path $ProjectRoot $candidate
  if (Test-Path $p) { $projGradle = $p; break }
}

if (-not $projGradle) {
  Write-Host '[!] No project-level android gradle file. Skip.' -ForegroundColor Yellow
}
elseif ((Get-Content $projGradle -Raw) -match 'maven\.aliyun\.com') {
  Write-Host '    Already contains Aliyun mirrors. Skipped.'
}
else {
  $pIsKts = $projGradle.EndsWith('.kts')
  if ($pIsKts) {
    $pRepoLines = @(
      '        maven { url = uri("https://maven.aliyun.com/repository/google") }',
      '        maven { url = uri("https://maven.aliyun.com/repository/central") }',
      '        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }'
    )
  }
  else {
    $pRepoLines = @(
      "        maven { url 'https://maven.aliyun.com/repository/google' }",
      "        maven { url 'https://maven.aliyun.com/repository/central' }",
      "        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }"
    )
  }
  $pContent = Get-Content $projGradle -Raw
  $nl = [Environment]::NewLine
  $bIdx = $pContent.IndexOf('allprojects')
  if ($bIdx -ge 0) {
    $rIdx = $pContent.IndexOf('repositories', $bIdx)
    if ($rIdx -ge 0) {
      $oIdx = $pContent.IndexOf('{', $rIdx)
      if ($oIdx -ge 0) {
        $insert = $nl + ($pRepoLines -join $nl) + $nl
        $pContent = $pContent.Substring(0, $oIdx + 1) + $insert + $pContent.Substring($oIdx + 1)
        [System.IO.File]::WriteAllText($projGradle, $pContent)
        Write-Host '    Injected Aliyun mirrors into allprojects.repositories'
      }
    }
  }
}

# ---------- 2) settings.gradle(.kts) -> Aliyun repos on top (fallback kept) ----------
Step 'Checking settings.gradle repositories (Aliyun on top, idempotent)'
$settingsFile = $null
foreach ($candidate in @('android\settings.gradle.kts', 'android\settings.gradle')) {
  $p = Join-Path $ProjectRoot $candidate
  if (Test-Path $p) { $settingsFile = $p; break }
}

if (-not $settingsFile) {
  Write-Host '[!] No android settings file yet. Skip mirror injection.' -ForegroundColor Yellow
}
elseif ((Get-Content $settingsFile -Raw) -match 'maven\.aliyun\.com') {
  Write-Host '    Already contains Aliyun mirrors. Skipped.'
}
else {
  $isKts = $settingsFile.EndsWith('.kts')
  if ($isKts) {
    # Kotlin DSL syntax
    $repoLines = @(
      '        maven { url = uri("https://maven.aliyun.com/repository/google") }',
      '        maven { url = uri("https://maven.aliyun.com/repository/central") }',
      '        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }'
    )
  }
  else {
    # Groovy DSL syntax
    $repoLines = @(
      "        maven { url 'https://maven.aliyun.com/repository/google' }",
      "        maven { url 'https://maven.aliyun.com/repository/central' }",
      "        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }"
    )
  }
  $sContent = Get-Content $settingsFile -Raw
  $nl = [Environment]::NewLine
  foreach ($block in @('pluginManagement', 'dependencyResolutionManagement')) {
    $bIdx = $sContent.IndexOf($block)
    if ($bIdx -lt 0) { continue }
    $rIdx = $sContent.IndexOf('repositories', $bIdx)
    if ($rIdx -lt 0) { continue }
    $oIdx = $sContent.IndexOf('{', $rIdx)
    if ($oIdx -lt 0) { continue }
    $insert = $nl + ($repoLines -join $nl) + $nl
    $sContent = $sContent.Substring(0, $oIdx + 1) + $insert + $sContent.Substring($oIdx + 1)
    Write-Host ('    Injected Aliyun mirrors into ' + $block + '.repositories')
  }
  # Write back UTF-8 WITHOUT BOM (Groovy/Kotlin DSL safe)
  [System.IO.File]::WriteAllText($settingsFile, $sContent)
}

# ---------- 3) Resolve dependencies ----------
Step 'flutter pub get'
& flutter pub get
CheckExit 'flutter pub get'

# ---------- 4) Code generation (drift etc.) ----------
Step 'dart run build_runner build --delete-conflicting-outputs'
& dart run build_runner build --delete-conflicting-outputs
CheckExit 'build_runner'

# ---------- 5) Static analysis (gate: 0 errors) ----------
# 说明：flutter analyze 对任何告警（含历史 info/warning）都返回非零退出码，
# 直接 CheckExit 会把存量告警误判为失败。门禁意图是「0 error」，故改为只统计
# 真正以 空格+error 开头的行（warning/info 放行，历史存量不阻塞构建）。
Step 'flutter analyze (requirement: 0 error)'
# 只抓 stdout（告警/error 行）；stderr 横幅（"Flutter assets will be downloaded..."）
# 在 $ErrorActionPreference='Stop' 下经 2>&1 会被误抛 NativeCommandError，故不合并。
$anReport = & flutter analyze | Out-String
$anErrorCount = [regex]::Matches($anReport, '(?m)^\s*error').Count
if ($anErrorCount -gt 0) {
  Write-Host ("[X] flutter analyze found " + $anErrorCount + " error(s), aborting build.") -ForegroundColor Red
  exit 1
}
$anOtherCount = [regex]::Matches($anReport, '(?m)^\s*(warning|info)').Count
Write-Host ("    flutter analyze: 0 errors, " + $anOtherCount + " warnings/infos (historical)")

# ---------- 6) Unit / widget tests (gate: all green) ----------
Step 'flutter test (requirement: all green)'
& flutter test
CheckExit 'flutter test'

# ---------- 7) Build debug APK ----------
Step 'flutter build apk --debug'
& flutter build apk --debug
CheckExit 'flutter build apk --debug'

$apk = Join-Path $ProjectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
if (Test-Path $apk) {
  Write-Host ''
  Write-Host ('[OK] Build finished: ' + $apk) -ForegroundColor Green
}
else {
  Write-Host '[!] Build succeeded but expected APK path not found. Check output above.' -ForegroundColor Yellow
}
