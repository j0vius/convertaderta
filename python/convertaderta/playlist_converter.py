from __future__ import annotations

import os
from typing import Callable, Optional

from .csv_parser import DjayCsvParser
from .local_index import LocalMusicIndex
from .m3u8_writer import M3u8Writer
from .models import ConversionProgress, ConversionResult, DjayTrack, TrackResolution
from .music_lookup import MusicLookupError, MusicTrackLookup
from .track_resolver import TrackResolver


class PlaylistConverter:
    def __init__(self) -> None:
        self.parser = DjayCsvParser()
        self.resolver = TrackResolver()
        self.writer = M3u8Writer()
        self.music_lookup = MusicTrackLookup()
        self.local_index: Optional[LocalMusicIndex] = None
        self.last_warning: Optional[str] = None

    def parse_tracks(self, csv_path: str) -> list[DjayTrack]:
        tracks = self.parser.parse_file(csv_path)
        return self.resolver.resolve_all(tracks)

    def resolve_tracks(
        self,
        tracks: list[DjayTrack],
        on_progress: Optional[Callable[[ConversionProgress], None]] = None,
    ) -> list[DjayTrack]:
        self.last_warning = None

        if self.local_index is None:
            if on_progress:
                on_progress(
                    ConversionProgress(
                        phase="scanning_local",
                        current=0,
                        total=len(tracks),
                        detail="Searching local music folders for audio files…",
                    )
                )

            def scan_progress(count: int) -> None:
                if on_progress:
                    on_progress(
                        ConversionProgress(
                            phase="scanning_local",
                            current=count,
                            total=len(tracks),
                            detail=f"Indexed {count} local audio files…",
                        )
                    )

            self.local_index = LocalMusicIndex.build(on_file_indexed=scan_progress)

        needs_music_lookup = [track for track in tracks if track.resolution is TrackResolution.MUSIC_LIBRARY]
        music_lookup_index = 0
        resolved_tracks: list[DjayTrack] = []

        for track in tracks:
            if track.resolution is TrackResolution.LOCAL_FILE:
                resolved_tracks.append(track)
                continue

            if track.resolution is not TrackResolution.MUSIC_LIBRARY:
                resolved_tracks.append(track)
                continue

            updated = track
            local_path = self.local_index.find_path(track.title, track.artist) if self.local_index else None
            if local_path and os.path.isfile(local_path):
                updated.resolution = TrackResolution.LOCAL_FILE
                updated.resolved_path = local_path
                resolved_tracks.append(updated)
                continue

            music_lookup_index += 1
            if on_progress:
                on_progress(
                    ConversionProgress(
                        phase="matching_music",
                        current=music_lookup_index,
                        total=len(needs_music_lookup),
                        detail=f"{track.title} — {track.artist}",
                    )
                )

            try:
                music_path = self.music_lookup.lookup_path(track.title, track.artist)
                if music_path and os.path.isfile(music_path):
                    updated.resolution = TrackResolution.LOCAL_FILE
                    updated.resolved_path = music_path
                    resolved_tracks.append(updated)
                    continue
            except MusicLookupError as exc:
                self.last_warning = str(exc)

            updated.resolution = TrackResolution.MISSING_FILE
            updated.resolved_path = track.url
            resolved_tracks.append(updated)

        return resolved_tracks

    def convert(
        self,
        csv_path: str,
        output_path: Optional[str] = None,
        on_progress: Optional[Callable[[ConversionProgress], None]] = None,
    ) -> ConversionResult:
        if on_progress:
            on_progress(
                ConversionProgress(
                    phase="preparing",
                    current=0,
                    total=0,
                    detail="Reading playlist from CSV…",
                )
            )

        tracks = self.parse_tracks(csv_path)
        tracks = self.resolve_tracks(tracks, on_progress=on_progress)

        if on_progress:
            on_progress(
                ConversionProgress(
                    phase="writing",
                    current=1,
                    total=1,
                    detail="Saving M3U8 file…",
                )
            )

        destination = output_path or self.writer.default_output_path(csv_path)
        return self.writer.write(tracks, destination)
