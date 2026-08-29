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
flutter build web --release