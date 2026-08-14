#!/bin/bash
# 构建分发 DMG：mdPresenter.app + 「Applications」快捷方式（拖放安装布局）。
# 用法:
#   ./scripts/make-dmg.sh           # 本机架构
#   UNIVERSAL=1 ./scripts/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL="${UNIVERSAL:-0}" ./scripts/make-app.sh

mkdir -p dist
if [ "${UNIVERSAL:-0}" = "1" ]; then
    DMG="dist/mdPresenter-macOS-universal.dmg"
else
    DMG="dist/mdPresenter-macOS-$(uname -m).dmg"
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R .build/app-bundle/mdPresenter.app "$STAGE/"
# 经典的拖放安装布局：Applications 快捷方式。
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "mdPresenter" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

shasum -a 256 "$DMG" | tee "$DMG.sha256"

echo "✅ 完成: $DMG"
echo "   校验: $(cat "$DMG.sha256")"
