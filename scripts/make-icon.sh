#!/bin/bash
# 生成 mdPresenter 应用图标（1024 PNG + 全套 .icns）。
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Assets

swift scripts/icon-gen.swift Assets/mdPresenter-icon-1024.png

ICONSET="$(mktemp -d)/mdPresenter.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z "$s" "$s" Assets/mdPresenter-icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d" Assets/mdPresenter-icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Assets/mdPresenter.icns

echo "✅ 图标已生成: Assets/mdPresenter.icns + Assets/mdPresenter-icon-1024.png"
