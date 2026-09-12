#!/bin/bash
# Render Resources/d2note-icon.svg -> build/d2note.icns
set -euo pipefail
cd "$(dirname "$0")/.."
SVG="Resources/d2note-icon.svg"
OUT="${1:-build/d2note.icns}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> rendering $SVG"
qlmanage -t -s 1024 -o "$TMP" "$SVG" >/dev/null 2>&1 || true
PNG="$TMP/$(basename "$SVG").png"
if [ ! -s "$PNG" ]; then
    echo "qlmanage failed, falling back to AppKit renderer"
    swift tools/MakeIcon.swift
    PNG="build/icon.iconset/icon_512x512@2x.png"
fi

ICONSET="$TMP/d2note.iconset"
mkdir -p "$ICONSET"
for spec in 16:icon_16x16 32:icon_16x16@2x 32:icon_32x32 64:icon_32x32@2x 128:icon_128x128 256:icon_128x128@2x 256:icon_256x256 512:icon_256x256@2x 512:icon_512x512 1024:icon_512x512@2x; do
    size="${spec%%:*}"; name="${spec##*:}"
    sips -z $size $size "$PNG" --out "$ICONSET/$name.png" >/dev/null
done
mkdir -p "$(dirname "$OUT")"
iconutil -c icns "$ICONSET" -o "$OUT"
echo "==> wrote $OUT"
