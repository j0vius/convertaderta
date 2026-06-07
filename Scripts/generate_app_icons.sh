#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${1:-$ROOT/DjayPlaylistBridge/Assets.xcassets/AppIcon.appiconset/source-mascot.png}"
ICON_SET="$ROOT/DjayPlaylistBridge/Assets.xcassets/AppIcon.appiconset"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ ! -f "$SOURCE" ]]; then
  echo "Source image not found: $SOURCE" >&2
  exit 1
fi

# Square master at 1024px. Keep alpha so rounded corners stay transparent.
cp "$SOURCE" "$WORK/source.png"
WIDTH=$(sips -g pixelWidth "$WORK/source.png" | awk '/pixelWidth/ {print $2}')
HEIGHT=$(sips -g pixelHeight "$WORK/source.png" | awk '/pixelHeight/ {print $2}')
CROP=$(( WIDTH < HEIGHT ? WIDTH : HEIGHT ))
sips -c "$CROP" "$CROP" "$WORK/source.png" --out "$WORK/square.png" >/dev/null
sips -z 1024 1024 "$WORK/square.png" --out "$WORK/master.png" >/dev/null

write_icon() {
  local filename="$1"
  local size="$2"
  sips -z "$size" "$size" "$WORK/master.png" --out "$ICON_SET/$filename" >/dev/null
}

write_icon icon_16x16.png 16
write_icon icon_16x16@2x.png 32
write_icon icon_32x32.png 32
write_icon icon_32x32@2x.png 64
write_icon icon_128x128.png 128
write_icon icon_128x128@2x.png 256
write_icon icon_256x256.png 256
write_icon icon_256x256@2x.png 512
write_icon icon_512x512.png 512
write_icon icon_512x512@2x.png 1024

echo "Generated app icons in $ICON_SET"
