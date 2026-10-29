#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:?destination resources directory required}"
SRC="$ROOT/Vendor/MediaRemoteAdapter"
FRAMEWORK="$SRC/build/MediaRemoteAdapter.framework"

if [ ! -f "$FRAMEWORK/Versions/A/MediaRemoteAdapter" ]; then
    "$ROOT/scripts/build-mediaremote-adapter.sh"
fi

mkdir -p "$DEST/NowPlaying"
cp "$SRC/bin/mediaremote-adapter.pl" "$DEST/NowPlaying/mediaremote-adapter.pl"
rm -rf "$DEST/NowPlaying/MediaRemoteAdapter.framework"
cp -R "$FRAMEWORK" "$DEST/NowPlaying/MediaRemoteAdapter.framework"
codesign --force --sign - "$DEST/NowPlaying/MediaRemoteAdapter.framework"
