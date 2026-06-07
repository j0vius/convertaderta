from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Optional


class MusicImportError(Exception):
    pass


class MusicPlaylistBuilder:
    def import_playlist(self, m3u8_path: str) -> None:
        paths = self._parse_file_paths(m3u8_path)
        if not paths:
            raise MusicImportError("The M3U8 file contains no playable file paths.")

        playlist_name = Path(m3u8_path).stem
        if sys.platform == "darwin":
            self._import_macos(playlist_name, paths)
        elif sys.platform == "win32":
            self._import_windows(playlist_name, paths)
        else:
            raise MusicImportError("Import to Apple Music is only supported on macOS and Windows.")

    def _parse_file_paths(self, m3u8_path: str) -> list[str]:
        lines = Path(m3u8_path).read_text(encoding="utf-8").splitlines()
        return [
            line.strip()
            for line in lines
            if line.strip() and not line.startswith("#")
        ]

    def _import_macos(self, playlist_name: str, paths: list[str]) -> None:
        added = 0
        escaped_name = self._escape_applescript(playlist_name)

        for path in paths:
            if not os.path.isfile(path):
                continue
            escaped_path = self._escape_applescript(path)
            script = f'''
            tell application "Music"
                set playlistName to "{escaped_name}"
                if not (exists playlist playlistName) then
                    make new playlist with properties {{name:playlistName}}
                end if
                set targetPlaylist to playlist playlistName
                set trackFile to POSIX file "{escaped_path}"
                add trackFile to targetPlaylist
            end tell
            '''
            try:
                self._run_osascript(script, timeout=20)
                added += 1
            except MusicImportError as exc:
                if "Automation" in str(exc) or "authorized" in str(exc).lower():
                    raise
                continue

        if added == 0:
            raise MusicImportError(
                "No tracks could be added. Check that files still exist at the paths in the M3U8."
            )

        reveal_script = f'''
        tell application "Music"
            activate
            set playlistName to "{escaped_name}"
            if exists playlist playlistName then
                reveal playlist playlistName
            end if
        end tell
        '''
        try:
            self._run_osascript(reveal_script, timeout=10)
        except MusicImportError:
            pass

    def _import_windows(self, playlist_name: str, paths: list[str]) -> None:
        try:
            import win32com.client  # type: ignore
        except ImportError as exc:
            raise MusicImportError(
                "Windows import requires pywin32. Reinstall convertaderta from the latest release."
            ) from exc

        try:
            itunes = win32com.client.Dispatch("iTunes.Application")
        except Exception as exc:
            raise MusicImportError(
                "Could not open Apple Music / iTunes. Install Apple Music for Windows and try again."
            ) from exc

        added = 0
        playlist = None

        for path in paths:
            if not os.path.isfile(path):
                continue
            windows_path = os.path.normpath(path)
            try:
                if playlist is None:
                    playlist = itunes.CreatePlaylist(playlist_name)
                playlist.AddFile(windows_path)
                added += 1
            except Exception:
                continue

        if added == 0:
            raise MusicImportError(
                "No tracks could be added. Check that files still exist at the paths in the M3U8."
            )

        try:
            itunes.BringToFront()
        except Exception:
            pass

    @staticmethod
    def _escape_applescript(value: str) -> str:
        return value.replace("\\", "\\\\").replace('"', '\\"')

    def _run_osascript(self, script: str, timeout: int) -> str:
        try:
            completed = subprocess.run(
                ["/usr/bin/osascript", "-e", script],
                capture_output=True,
                text=True,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired as exc:
            raise MusicImportError("Timed out talking to Music.") from exc

        if completed.returncode != 0:
            error = completed.stderr.strip()
            if "not authorized" in error.lower() or "-1743" in error:
                raise MusicImportError(
                    "Allow convertaderta to control Music in System Settings → Privacy & Security → Automation."
                )
            raise MusicImportError(error or "Music returned an error.")

        return completed.stdout.strip()
