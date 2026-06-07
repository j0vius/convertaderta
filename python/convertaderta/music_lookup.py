from __future__ import annotations

import os
import subprocess
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Optional
from urllib.parse import unquote


class MusicLookupError(Exception):
    pass


class MusicTrackLookup:
    def lookup_path(self, title: str, artist: str) -> Optional[str]:
        if sys.platform == "darwin":
            return self._lookup_macos(title, artist)
        if sys.platform == "win32":
            return self._lookup_windows(title, artist)
        return None

    def _lookup_macos(self, title: str, artist: str) -> Optional[str]:
        primary_artist = artist.split(",")[0].strip() if artist else artist
        query = self._escape_applescript(f"{title} {primary_artist}")
        escaped_title = self._escape_applescript(title)
        escaped_artist = self._escape_applescript(primary_artist)

        script = f'''
        tell application "Music"
            set foundTracks to (search library playlist 1 for "{query}" only songs)
            repeat with t in foundTracks
                if name of t contains "{escaped_title}" and artist of t contains "{escaped_artist}" then
                    try
                        return POSIX path of ((location of t) as alias)
                    end try
                end if
            end repeat
            if (count of foundTracks) > 0 then
                set t to item 1 of foundTracks
                try
                    return POSIX path of ((location of t) as alias)
                end try
            end if
            return ""
        end tell
        '''
        output = self._run_osascript(script, timeout=15)
        return output or None

    def _lookup_windows(self, title: str, artist: str) -> Optional[str]:
        for library_path in self._windows_library_paths():
            path = self._lookup_in_itunes_xml(library_path, title, artist)
            if path and os.path.isfile(path):
                return path
        return None

    def _windows_library_paths(self) -> list[Path]:
        home = Path.home()
        return [
            home / "Music" / "iTunes" / "iTunes Music Library.xml",
            home / "Music" / "iTunes" / "iTunes Library.xml",
            home / "Music" / "Apple Music" / "Apple Music Library.xml",
            home / "My Music" / "iTunes" / "iTunes Music Library.xml",
        ]

    def _lookup_in_itunes_xml(self, library_path: Path, title: str, artist: str) -> Optional[str]:
        if not library_path.exists():
            return None

        normalized_title = self._normalize(title)
        artist_variants = self._artist_variants(artist)

        try:
            tree = ET.parse(library_path)
            root = tree.getroot()
        except ET.ParseError:
            return None

        for dict_node in root.iter("dict"):
            fields = self._parse_plist_dict(dict_node)
            if fields.get("Media Type") not in (None, "Music", 1, "1"):
                continue

            track_title = fields.get("Name", "")
            track_artist = fields.get("Artist", "")
            location = fields.get("Location")
            if not location:
                continue

            if not self._title_artist_match(normalized_title, track_title, artist_variants, track_artist):
                continue

            path = self._decode_location(str(location))
            if path:
                return path

        return None

    def _parse_plist_dict(self, dict_node: ET.Element) -> dict:
        values: dict = {}
        key: Optional[str] = None
        for child in list(dict_node):
            tag = child.tag
            if tag == "key":
                key = child.text
            elif key is not None:
                if tag == "true":
                    values[key] = True
                elif tag == "false":
                    values[key] = False
                else:
                    values[key] = child.text
                key = None
        return values

    def _decode_location(self, location: str) -> Optional[str]:
        decoded = unquote(location)
        if decoded.lower().startswith("file://localhost/"):
            decoded = decoded[len("file://localhost/") :]
        elif decoded.lower().startswith("file:///"):
            decoded = decoded[len("file:///") :]
        elif decoded.lower().startswith("file://"):
            decoded = decoded[len("file://") :]

        if os.name == "nt":
            decoded = decoded.replace("/", "\\")
        return os.path.normpath(decoded)

    def _title_artist_match(
        self,
        normalized_title: str,
        track_title: str,
        artist_variants: list[str],
        track_artist: str,
    ) -> bool:
        candidate_title = self._normalize(track_title)
        if normalized_title not in candidate_title and candidate_title not in normalized_title:
            return False

        normalized_track_artist = self._normalize(track_artist)
        return any(
            self._normalize(variant) in normalized_track_artist
            or normalized_track_artist in self._normalize(variant)
            for variant in artist_variants
        )

    @staticmethod
    def _artist_variants(artist: str) -> list[str]:
        variants = [artist]
        variants.extend(part.strip() for part in artist.split(","))
        variants.extend(part.strip() for part in artist.split("/"))
        return list(dict.fromkeys(v for v in variants if v))

    @staticmethod
    def _normalize(value: str) -> str:
        folded = unicodedata.normalize("NFKD", value)
        ascii_only = "".join(ch for ch in folded if not unicodedata.combining(ch))
        return ascii_only.replace("@", "").lower().replace("_", " ")

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
            raise MusicLookupError("Timed out looking up track in Music.") from exc

        if completed.returncode != 0:
            error = completed.stderr.strip()
            if "not authorized" in error.lower() or "-1743" in error:
                raise MusicLookupError(self._automation_message())
            if error:
                raise MusicLookupError(error)
            raise MusicLookupError("Could not query Music for this track.")

        return completed.stdout.strip()

    @staticmethod
    def _automation_message() -> str:
        if sys.platform == "darwin":
            return (
                "Allow convertaderta to control Music:\n"
                "System Settings → Privacy & Security → Automation → enable Music for convertaderta.\n"
                "Then quit and reopen the app."
            )
        return (
            "Allow convertaderta to access Apple Music / iTunes on Windows, "
            "then reopen the app."
        )
