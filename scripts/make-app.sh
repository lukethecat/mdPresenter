#!/bin/bash
# 将 Presenter 打包为可双击运行的 macOS 应用。
# 用法: ./scripts/make-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Presenter"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "==> 构建 Release 版本…"
swift build -c release

echo "==> 组装 $APP_DIR …"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/Presenter" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Presenter</string>
    <key>CFBundleDisplayName</key>
    <string>Presenter</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.presenter.clone</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Presenter</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>致敬 iA Presenter 的学习项目，非官方产品。</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> 临时签名（Apple Silicon 本地运行必需）…"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "✅ 完成: $APP_DIR"
echo "双击即可运行，或: open \"$APP_DIR\""
