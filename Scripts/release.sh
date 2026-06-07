#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Building standalone release for convertaderta"
echo

"$ROOT_DIR/Scripts/build_release.sh"
"$ROOT_DIR/Scripts/create_dmg.sh"

echo
echo "Done."
echo "  App: $ROOT_DIR/dist/convertaderta.app"
echo "  DMG: $ROOT_DIR/dist/convertaderta.dmg"
