#!/bin/bash
# 将 mdPresenter 打包为可双击运行的 macOS 应用。
# 用法:
#   ./scripts/make-app.sh              # 本机架构
#   UNIVERSAL=1 ./scripts/make-app.sh  # Intel + Apple Silicon 通用二进制
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="mdPresenter"
BIN_NAME="Presenter"
BUNDLE_ID="com.mdpresenter.app"
OUT_DIR=".build/app-bundle"

echo "==> 构建 Release 版本 (${UNIVERSAL:+universal}${UNIVERSAL:-native})…"
if [ "${UNIVERSAL:-0}" = "1" ]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$BIN_NAME"
else
    swift build -c release
    BIN_PATH="$(swift build -c release --show-bin-path)/$BIN_NAME"
fi

APP_DIR="$OUT_DIR/$APP_NAME.app"
echo "==> 组装 $APP_DIR …"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$BIN_NAME"

# 应用图标（iA Writer 式极简：白底 + ".>" 渐变符号）。
./scripts/make-icon.sh >/dev/null
cp Assets/mdPresenter.icns "$APP_DIR/Contents/Resources/mdPresenter.icns"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>mdPresenter</string>
    <key>CFBundleDisplayName</key>
    <string>mdPresenter</string>
    <key>CFBundleIdentifier</key>
    <string>com.mdpresenter.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Presenter</string>
    <key>CFBundleIconFile</key>
    <string>mdPresenter.icns</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT 协议开源，由 DeepSeek Harness 协作开发。致敬 iA Presenter，非官方产品。</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> 临时签名（本地运行必需）…"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "✅ 完成: $APP_DIR"
if [ "${UNIVERSAL:-0}" = "1" ]; then
    lipo -info "$APP_DIR/Contents/MacOS/$BIN_NAME"
fi
echo "双击即可运行，或: open \"$APP_DIR\""
