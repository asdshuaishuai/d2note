#!/bin/bash
# Build d2note.app (release) into build/
set -euo pipefail
cd "$(dirname "$0")"

echo "==> swift build (release)"
swift build -c release

APP="build/d2note.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> assembling bundle"
cp .build/release/d2note "$APP/Contents/MacOS/d2note"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ -f "build/d2note.icns" ]; then
    cp build/d2note.icns "$APP/Contents/Resources/d2note.icns"
# 声明中文支持：让系统提供的菜单项（剪切/拷贝/粘贴等）显示中文
mkdir -p "$APP/Contents/Resources/zh-Hans.lproj"
mkdir -p "$APP/Contents/Resources/en.lproj"
else
    echo "    (no icon found — run: swift tools/MakeIcon.swift && iconutil -c icns build/icon.iconset -o build/d2note.icns)"
fi

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "==> done: $APP"
echo "    open with: open $APP"
