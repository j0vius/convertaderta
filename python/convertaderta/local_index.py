from __future__ import annotations

import os
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional

AUDIO_EXTENSIONS = {".mp3", ".flac", ".wav", ".m4a", ".aiff", ".aif", ".aac"}


@dataclass
class LocalEntry:
    file_name: str
    normalized_file_name: str
    path: str


class LocalMusicIndex:
    def __init__(self, entries: list[LocalEntry]) -> None:
        self.entries = entries

    @classmethod
    def build(
        cls,
        extra_roots: Optional[list[Path]] = None,
        on_file_indexed: Optional[Callable[[int], None]] = None,
    ) -> "LocalMusicIndex":
        home = Path.home()
        roots = [
            home / "Documents" / "music /Djay",
            home / "Documents" / "music",
            home / "Music",
            home / "Music" / "iTunes" / "iTunes Media",
        ]
        if extra_roots:
            roots.extend(extra_roots)

        seen: set[str] = set()
        collected: list[LocalEntry] = []

        for root in roots:
            if not root.exists():
                continue
            for dirpath, _, filenames in os.walk(root):
                for filename in filenames:
                    extension = Path(filename).suffix.lower()
                    if extension not in AUDIO_EXTENSIONS:
                        continue
                    full_path = os.path.normpath(os.path.join(dirpath, filename))
                    if full_path in seen:
                        continue
                    seen.add(full_path)
                    stem = Path(filename).stem
                    collected.append(
                        LocalEntry(
                            file_name=stem,
                            normalized_file_name=cls._normalize(stem),
                            path=full_path,
                        )
                    )
                    if on_file_indexed and len(collected) % 25 == 0:
                        on_file_indexed(len(collected))

        if on_file_indexed and collected:
            on_file_indexed(len(collected))

        return cls(collected)

    def find_path(self, title: str, artist: str) -> Optional[str]:
        normalized_title = self._normalize(title)
        title_tokens = self._significant_tokens(normalized_title)
        if not title_tokens:
            return None

        for primary_artist in self._artist_variants(artist):
            normalized_artist = self._normalize(primary_artist)
            candidates = [
                entry
                for entry in self.entries
                if all(token in entry.normalized_file_name for token in title_tokens)
                and (
                    not normalized_artist
                    or normalized_artist in entry.normalized_file_name
                    or all(
                        len(token) > 2 and token in entry.normalized_file_name
                        for token in normalized_artist.split()
                    )
                )
            ]

            if len(candidates) == 1:
                return candidates[0].path

            if candidates:
                best = max(
                    candidates,
                    key=lambda entry: self._score(entry, normalized_title, normalized_artist),
                )
                return best.path

        return None

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
        return (
            ascii_only.replace("@", "")
            .lower()
            .replace("_", " ")
        )

    def _significant_tokens(self, normalized_title: str) -> list[str]:
        stripped = (
            normalized_title.replace("(", " ")
            .replace(")", " ")
            .replace("-", " ")
            .replace("'", " ")
        )
        return [token for token in stripped.split() if len(token) > 2][:4]

    @staticmethod
    def _score(entry: LocalEntry, title: str, artist: str) -> int:
        value = 0
        if title in entry.normalized_file_name:
            value += 10
        if artist and artist in entry.normalized_file_name:
            value += 5
        return value
