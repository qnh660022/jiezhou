# ============================================================
# apply_android_overrides.ps1 - Idempotent post-flutter-create patcher.
#   1) applicationId -> com.travel.assistant.v2  (build.gradle / .kts)
#   2) android:label    -> Chinese app name (built from unicode points,
#      so THIS SCRIPT STAYS PURE ASCII on purpose)
# Safe to re-run any number of times.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\apply_android_overrides.ps1
# ============================================================
param(
  [string]$ProjectRoot = 'D:\AI\money2.0'
)
$ErrorActionPreference = 'Stop'

$appId = 'com.travel.assistant.v2'
# UTF-16 code points for the Chinese app name (keeps this file pure ASCII):
# U+65C5 U+9014 U+52A9 U+624B
$labelChars = @(0x65C5, 0x9014, 0x52A9, 0x624B)
$appLabel = -join ($labelChars | ForEach-Object { [char]$_ })
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ---------- 1) applicationId ----------
$gradleKts = Join-Path $ProjectRoot 'android\app\build.gradle.kts'
$gradleGroovy = Join-Path $ProjectRoot 'android\app\build.gradle'
$gradleFile = $null
$isKts = $false
if (Test-Path $gradleKts) { $gradleFile = $gradleKts; $isKts = $true }
elseif (Test-Path $gradleGroovy) { $gradleFile = $gradleGroovy }

if (-not $gradleFile) {
  Write-Host '[X] android/app/build.gradle(.kts) not found. Run flutter create first.' -ForegroundColor Red
  exit 1
}

$gContent = [System.IO.File]::ReadAllText($gradleFile)
if ($gContent.Contains($appId)) {
  Write-Host 'applicationId already correct. Skipped.'
}
else {
  if ($isKts) {
    $pattern = 'applicationId\s*=\s*"[^"]*"'
    $replacement = 'applicationId = "' + $appId + '"'
  }
  else {
    $pattern = 'applicationId\s+"[^"]*"'
    $replacement = 'applicationId "' + $appId + '"'
  }
  $updated = [regex]::Replace($gContent, $pattern, $replacement)
  if ($updated -eq $gContent) {
    Write-Host '[X] applicationId pattern not found in gradle file.' -ForegroundColor Red
    exit 1
  }
  [System.IO.File]::WriteAllText($gradleFile, $updated, $utf8NoBom)
  Write-Host ('applicationId patched -> ' + $appId)
}

# ---------- 2) android:label ----------
$manifest = Join-Path $ProjectRoot 'android\app\src\main\AndroidManifest.xml'
if (-not (Test-Path $manifest)) {
  Write-Host '[X] AndroidManifest.xml not found.' -ForegroundColor Red
  exit 1
}
$mContent = [System.IO.File]::ReadAllText($manifest)
$mPattern = 'android:label="[^"]*"'
$mReplacement = 'android:label="' + $appLabel + '"'
$mUpdated = [regex]::Replace($mContent, $mPattern, $mReplacement)
if ($mUpdated -eq $mContent) {
  Write-Host '[X] android:label attribute not found in manifest.' -ForegroundColor Red
  exit 1
}
[System.IO.File]::WriteAllText($manifest, $mUpdated, $utf8NoBom)
Write-Host ('android:label patched (unicode points: ' + (($labelChars | ForEach-Object { $_.ToString('X4') }) -join ' ') + ')')
Write-Host '[OK] Android overrides applied.' -ForegroundColor Green
