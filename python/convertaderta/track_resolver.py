from __future__ import annotations

import os
from pathlib import Path
from urllib.parse import unquote, urlparse, parse_qs

from .models import DjayTrack, TrackResolution


class TrackResolver:
    def resolve_all(self, tracks: list[DjayTrack]) -> list[DjayTrack]:
        return [self.resolve(track) for track in tracks]

    def resolve(self, track: DjayTrack) -> DjayTrack:
        resolution, path = self.resolve_url(track.url)
        track.resolution = resolution
        track.resolved_path = path
        return track

    def resolve_url(self, url_string: str) -> tuple[TrackResolution, str]:
        trimmed = url_string.strip()
        if not trimmed:
            return TrackResolution.MISSING_FILE, ""

        lower = trimmed.lower()

        if lower.startswith("ipod-library://"):
            library_id = self._extract_library_id(trimmed) or trimmed
            return TrackResolution.MUSIC_LIBRARY, library_id

        if lower.startswith("file://"):
            return self._resolve_file_path(self._extract_file_path(trimmed))

        if trimmed.startswith("/") or trimmed.startswith("~"):
            expanded = str(Path(trimmed).expanduser())
            return self._resolve_file_path(expanded)

        if len(trimmed) > 2 and trimmed[1] == ":" and trimmed[0].isalpha():
            return self._resolve_file_path(trimmed)

        return TrackResolution.MISSING_FILE, trimmed

    def _resolve_file_path(self, path: str) -> tuple[TrackResolution, str]:
        if not path:
            return TrackResolution.MISSING_FILE, path
        normalized = os.path.normpath(path)
        if os.path.isfile(normalized):
            return TrackResolution.LOCAL_FILE, normalized
        return TrackResolution.MISSING_FILE, normalized

    def _extract_file_path(self, url_string: str) -> str:
        parsed = urlparse(url_string)
        if parsed.scheme == "file":
            path = unquote(parsed.path)
            if os.name == "nt" and path.startswith("/") and len(path) > 2 and path[2] == ":":
                path = path[1:]
            return os.path.normpath(path)

        path = unquote(url_string[len("file://") :])
        if path.startswith("localhost"):
            path = path[len("localhost") :]
        if not path.startswith(("/", "\\")) and not (len(path) > 1 and path[1] == ":"):
            path = "/" + path
        return os.path.normpath(path)

    def _extract_library_id(self, url_string: str) -> str | None:
        parsed = urlparse(url_string)
        values = parse_qs(parsed.query).get("id")
        return values[0] if values else None
