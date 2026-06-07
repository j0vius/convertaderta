#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
DERIVED_DATA="$DIST_DIR/DerivedData"
APP_NAME="convertaderta"
SCHEME="DjayPlaylistBridge"
PROJECT="$ROOT_DIR/DjayPlaylistBridge.xcodeproj"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: Full Xcode is required (not just Command Line Tools)." >&2
  echo "Install Xcode from the App Store, then run:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

echo "==> Cleaning previous build artifacts"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "==> Building Release app"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}" \
  CODE_SIGN_STYLE="${CODE_SIGN_STYLE:-Manual}" \
  CODE_SIGNING_ALLOWED=YES \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "error: Expected app not found at $BUILT_APP" >&2
  exit 1
fi

echo "==> Copying app to dist/"
cp -R "$BUILT_APP" "$DIST_DIR/${APP_NAME}.app"

echo "==> Release build ready"
echo "    $DIST_DIR/${APP_NAME}.app"
