#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/Smart Mouse.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SIGNING_IDENTITY="Smart Mouse Dev"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/SmartMouse" "$MACOS_DIR/Smart Mouse"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"

# ── App Icon ──
swift "$ROOT_DIR/Scripts/gen-icon.swift" "$RESOURCES_DIR" 2>/dev/null || echo "⚠️  图标生成失败 (非致命)"

# ── Sign ──
if security unlock-keychain -p "" "$HOME/Library/Keychains/smartmouse-build.keychain-db" 2>/dev/null; then
  if codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR" 2>/dev/null; then
    echo "✅ 签名成功"
  else
    echo "⚠️  签名失败 — 辅助功能权限可能需要重新授权"
  fi
else
  echo "⚠️  钥匙串解锁失败 — 签名跳过，权限可能不稳定"
fi

cat > "$RESOURCES_DIR/README.txt" <<'EOF'
Smart Mouse

Launch this app, then enable Accessibility permission in System Settings:
Privacy & Security > Accessibility > Smart Mouse.
EOF

echo "$APP_DIR"
