# build_web.ps1 - 本地构建 Web 并启动本地静态预览。
# 用法：
#   powershell -File scripts\build_web.ps1 [-Port 8080]
# 说明：Flutter 框架预设 / Docker 部署时此脚本同构产物（build/web）。
param(
  [int]$Port = 8080
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot 'env.local.ps1')
Set-Location $root

Write-Host '==> flutter build web --release' -ForegroundColor Cyan
# 先编译 drift Web worker
& dart compile js -O4 -o web\drift_worker.dart.js web\drift_worker.dart
& flutter build web --release
if ($LASTEXITCODE -ne 0) { Write-Host '[X] build failed' -ForegroundColor Red; exit 1 }

Write-Host '==> serving build/web ...' -ForegroundColor Cyan
# 用 Dart 自带的一个极简静态服务器（无第三方依赖）
& dart pub global list 2>$null | Out-Null
& python -m http.server $Port --directory build\web