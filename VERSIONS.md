# Version snapshots

## v1-working (2026-06-07)

**Tag:** `v1-working`

Working baseline for CSV → M3U8 conversion:

- Per-track Apple Music path lookup (no full-library scan hang)
- Progress bar with phase, percentage, and track counter
- Local folder scan (`Documents/music /Djay`, `Documents/music`)
- M3U8 export with resolved local paths

**Known limitation:** “Import to Apple Music” button does not work in this tag (Music.app has no `import` AppleScript command for M3U8). Use **File → Library → Import Playlist** in Music, or drag the `.m3u8` into Music manually.

### Restore v1

```bash
cd ~/Projects/DjayPlaylistBridge
./Scripts/restore-v1.sh
./Scripts/release.sh
```

Or manually:

```bash
git checkout v1-working
./Scripts/release.sh
```

### Save a new snapshot

```bash
git add -A
git commit -m "Describe your changes"
git tag -a v2-working -m "Optional description"
```
