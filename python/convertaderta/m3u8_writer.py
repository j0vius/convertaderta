from __future__ import annotations

import os
from pathlib import Path

from .duration_parser import parse_duration
from .models import ConversionResult, DjayTrack, TrackResolution


class M3u8WriterError(Exception):
    pass


class M3u8Writer:
    def write(self, tracks: list[DjayTrack], output_path: str) -> ConversionResult:
        local_tracks = [
            (track, track.resolved_path)
            for track in tracks
            if track.resolution is TrackResolution.LOCAL_FILE and track.resolved_path
        ]

        if not local_tracks:
            raise M3u8WriterError(
                "No local files were found. Make sure tracks exist in your music library with files on disk."
            )

        lines = ["#EXTM3U"]
        for track, path in local_tracks:
            duration = parse_duration(track.time) or -1
            label = f"{track.artist} - {track.title}"
            lines.append(f"#EXTINF:{duration},{label}")
            lines.append(path)

        output = Path(output_path)
        output.write_text("\n".join(lines) + "\n", encoding="utf-8")

        resolved = sum(1 for track in tracks if track.resolution is TrackResolution.LOCAL_FILE)
        missing = len(tracks) - resolved

        return ConversionResult(
            playlist_name=output.stem,
            output_path=str(output),
            tracks=tracks,
            resolved_count=resolved,
            missing_count=missing,
        )

    def default_output_path(self, csv_path: str) -> str:
        csv = Path(csv_path)
        return str(csv.with_suffix(".m3u8"))
