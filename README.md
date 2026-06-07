# convertaderta

Native macOS app that converts djay Pro CSV playlist exports into M3U8 playlists for Apple Music import.

## Why this exists

djay Pro can export playlists as CSV but cannot re-import them. This app converts those CSV files into extended M3U8 playlists that Apple Music accepts. You then drag the imported playlist back into djay Pro.

**Cue points and beat grids are not preserved** — they live in djay's internal database (`~/Music/djay/`), not in CSV exports.

## Requirements

- macOS 13 or later
- Xcode 15+ (to build)
- Apple Music app installed
- For catalog streaming track matching: Apple Music subscription + authorization

## Build

### Standalone release + DMG (for copying to another Mac)

Requires **full Xcode** (not just Command Line Tools):

```bash
cd ~/Projects/DjayPlaylistBridge
chmod +x Scripts/*.sh
./Scripts/release.sh
```

This produces:

- `dist/convertaderta.app` — standalone app, no Xcode/Swift needed to run
- `dist/convertaderta.dmg` — drag-and-drop installer for another Mac

On the target Mac: open the DMG → drag **convertaderta** to **Applications** → launch.

**First launch on another Mac:** if macOS blocks the app (unsigned build), right-click the app → **Open**, or run:

```bash
xattr -cr /Applications/convertaderta.app
```

The target Mac still needs **macOS 13+**, **Apple Music**, and **djay Pro** for the full playlist round-trip. It does **not** need Xcode or developer tools.

### Full macOS app — debug (requires Xcode)

```bash
cd ~/Projects/DjayPlaylistBridge
xcodebuild -scheme DjayPlaylistBridge -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/DjayPlaylistBridge.app
```

Or open `DjayPlaylistBridge.xcodeproj` in Xcode and press Cmd+R.

### Core library only (Command Line Tools)

```bash
cd ~/Projects/DjayPlaylistBridge
swift build
swift Scripts/verify_core.swift
```

## Run tests

Requires full Xcode (includes XCTest):

```bash
xcodebuild -scheme DjayPlaylistBridge -configuration Debug test
```

## Usage

### 1. Export from djay Pro

In djay Pro: open a playlist in **My Collection** → menu → **Export as CSV File…**

### 2. Convert

1. Launch convertaderta
2. Drop the CSV onto the window (or **File → Open CSV…**)
3. Review the track preview (Resolved / Missing / Streaming)
4. Click **Convert**
5. Optionally click **Import to Apple Music**

### 3. Import into Apple Music

The app can trigger this automatically. You can also do it manually:

- **File → Library → Import Playlist** in Music.app, or
- drag the `.m3u8` file into Music

### 4. Bring playlist into djay Pro

Open djay Pro and **drag** the imported playlist from Music/Local Files into **My Collection**.

## Streaming tracks

Tracks without a `file://` URL are marked **Streaming**. After conversion:

1. Click **Match Streaming Tracks** to search your Music library via AppleScript
2. If enabled, unmatched tracks are then searched in the Apple Music catalog via MusicKit

Catalog matching requires Apple Music authorization and an active subscription.

## CSV format

djay Pro exports these columns:

`Title, Artist, Album, Time, BPM, Key, URL`

**URL types djay uses:**

| URL format | Meaning |
|------------|---------|
| `file:///Users/.../track.mp3` | Local file path |
| `ipod-library://item/...?id=...` | Track in your Apple Music library (app looks it up via Music.app) |
| `apple-music://...` | Streaming / catalog track |

If your CSV uses `ipod-library://` URLs (common for tracks added via Apple Music), the app resolves them by searching your Music library. If tracks aren't stored as files on disk (cloud-only), the app creates the playlist directly in Music instead of an M3U8 file.

## Limitations

- No direct import into djay Pro (Algoriddim limitation)
- M3U8 requires audio files to exist at the paths in the CSV
- Moved or renamed files appear as **Missing**
- Streaming/catalog matching is best-effort
- Cue points, beatgrids, and loops are not restored

## Project structure

```
DjayPlaylistBridge/
├── DjayPlaylistBridge/          # App sources
├── DjayPlaylistBridgeTests/     # Unit tests + CSV fixtures
├── Scripts/
│   ├── build_release.sh         # Release .app build
│   ├── create_dmg.sh            # Package .app into .dmg
│   └── release.sh               # Build + DMG in one step
├── dist/                        # Release output (gitignored)
└── README.md
```
