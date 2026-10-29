#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Vendor/MediaRemoteAdapter"
OUT="$SRC/build/MediaRemoteAdapter.framework"

if [ ! -d "$SRC/src/adapter" ]; then
    echo "MediaRemote adapter source not found at $SRC" >&2
    exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT/Versions/A/Headers" "$OUT/Versions/A/Resources"
cp "$SRC/include/MediaRemoteAdapter.h" "$OUT/Versions/A/Headers/"
ln -sfn A "$OUT/Versions/Current"
ln -sfn Versions/Current/Headers "$OUT/Headers"
ln -sfn Versions/Current/Resources "$OUT/Resources"
ln -sfn Versions/Current/MediaRemoteAdapter "$OUT/MediaRemoteAdapter"

cat > "$OUT/Versions/A/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MediaRemoteAdapter</string>
    <key>CFBundleIdentifier</key>
    <string>com.bilou.MediaRemoteAdapter</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MediaRemoteAdapter</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.6</string>
</dict>
</plist>
PLIST

xcrun --sdk macosx clang -dynamiclib \
    -arch arm64 -arch x86_64 \
    -mmacosx-version-min=14.6 \
    -fobjc-arc -fvisibility=default \
    -install_name '@rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter' \
    -I "$SRC/include" -I "$SRC/src" \
    "$SRC/src/adapter/env.m" \
    "$SRC/src/adapter/get.m" \
    "$SRC/src/adapter/globals.m" \
    "$SRC/src/adapter/keys.m" \
    "$SRC/src/adapter/now_playing.m" \
    "$SRC/src/adapter/repeat.m" \
    "$SRC/src/adapter/seek.m" \
    "$SRC/src/adapter/send.m" \
    "$SRC/src/adapter/shuffle.m" \
    "$SRC/src/adapter/speed.m" \
    "$SRC/src/adapter/stream.m" \
    "$SRC/src/adapter/test.m" \
    "$SRC/src/private/MediaRemote.m" \
    "$SRC/src/utility/Debounce.m" \
    "$SRC/src/utility/helpers.m" \
    -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
    -o "$OUT/Versions/A/MediaRemoteAdapter"

codesign --force --sign - "$OUT"
