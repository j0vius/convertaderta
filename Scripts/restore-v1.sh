#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not a git repository. Run from a cloned DjayPlaylistBridge repo with tags."
  exit 1
fi

if ! git rev-parse v1-working >/dev/null 2>&1; then
  echo "Error: tag v1-working not found."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Warning: you have uncommitted changes. Stashing first…"
  git stash push -u -m "restore-v1 auto-stash $(date +%Y%m%d-%H%M%S)"
fi

git checkout v1-working
echo "Restored source tree to v1-working."
echo "Rebuild with: ./Scripts/release.sh"
