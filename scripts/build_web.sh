#!/usr/bin/env bash
# Vercel Web 构建脚本（Vercel 构建镜像不预装 Flutter，首次构建自动安装 SDK）。
# 本地 Windows 构建请用 scripts/build_web.ps1，不走本脚本。
set -euxo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_SDK="$HOME/flutter"
  if [ ! -d "$FLUTTER_SDK" ]; then
    echo "==> installing Flutter SDK (stable) ..."
    git clone --branch stable --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_SDK"
  fi
  export PATH="$FLUTTER_SDK/bin:$PATH"
fi

flutter pub get
dart run build_runner build --delete-conflicting-outputs
# 编译 drift Web worker（依赖 sqlite3.wasm 一并复制自 web/ 目录）
dart compile js -O4 -o web/drift_worker.dart.js web/drift_worker.dart

# ---------- 云端凭据注入（只读分享页 /s/<token> 的生死线） ----------
# SupabaseCfg 只认编译期 --dart-define（String.fromEnvironment），运行期
# 环境变量对它无效。此前本脚本没传这两个 define，导致线上 Web 包里
# SUPABASE_URL/ANON_KEY 全是空串 → cloudClientProvider 为 null →
# 分享页直接显示「端点未配置」，外链等于废链。
# 值取自部署平台（Vercel）环境变量，切勿写死进仓库。
if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "==> [WARN] SUPABASE_URL / SUPABASE_ANON_KEY 未设置：本次产物不含云端配置，只读分享页将不可用。" >&2
fi
DART_DEFINES=(
  "--dart-define=SUPABASE_URL=${SUPABASE_URL:-}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}"
)

flutter build web --release "${DART_DEFINES[@]}"