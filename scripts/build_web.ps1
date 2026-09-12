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

# 云端凭据注入（只读分享页 /s/<token> 的生死线）：
# SupabaseCfg 只认编译期 --dart-define，运行期环境变量对它无效。
# 值来自 env.local.ps1（已 gitignore，勿写死进仓库）。
if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) {
  Write-Host '[WARN] SUPABASE_URL / SUPABASE_ANON_KEY 未设置：产物不含云端配置，只读分享页将不可用。' -ForegroundColor Yellow
}
& flutter build web --release --dart-define=SUPABASE_URL=$env:SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY
if ($LASTEXITCODE -ne 0) { Write-Host '[X] build failed' -ForegroundColor Red; exit 1 }

Write-Host '==> serving build/web ...' -ForegroundColor Cyan
# 用 Dart 自带的一个极简静态服务器（无第三方依赖）
& dart pub global list 2>$null | Out-Null
& python -m http.server $Port --directory build\web