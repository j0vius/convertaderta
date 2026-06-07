from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class TrackResolution(Enum):
    LOCAL_FILE = "local_file"
    MISSING_FILE = "missing_file"
    MUSIC_LIBRARY = "music_library"

    @property
    def label(self) -> str:
        if self is TrackResolution.LOCAL_FILE:
            return "Resolved"
        if self is TrackResolution.MUSIC_LIBRARY:
            return "Pending"
        return "Missing"


@dataclass
class DjayTrack:
    title: str
    artist: str
    album: str
    time: str
    bpm: str
    key: str
    url: str
    resolution: TrackResolution = TrackResolution.MISSING_FILE
    resolved_path: str = ""

    @property
    def status_label(self) -> str:
        return self.resolution.label


@dataclass
class ConversionResult:
    playlist_name: str
    output_path: str
    tracks: list[DjayTrack]
    resolved_count: int
    missing_count: int

    @property
    def summary(self) -> str:
        return f"{self.resolved_count} resolved, {self.missing_count} missing"


@dataclass
class ConversionProgress:
    phase: str
    current: int
    total: int
    detail: str

    @property
    def phase_title(self) -> str:
        titles = {
            "preparing": "Preparing",
            "scanning_local": "Scanning local music",
            "matching_music": "Matching in Apple Music",
            "writing": "Writing playlist",
            "importing": "Importing to Apple Music",
        }
        return titles.get(self.phase, self.phase)

    @property
    def overall_fraction(self) -> float:
        if self.phase == "preparing":
            return 0.03
        if self.phase == "scanning_local":
            return min(0.05 + (self.current / 1200.0) * 0.25, 0.30)
        if self.phase == "matching_music":
            if self.total <= 0:
                return 0.35
            return 0.30 + (self.current / self.total) * 0.65
        if self.phase == "writing":
            return 0.98
        if self.phase == "importing":
            return 0.5
        return 0.0

    @property
    def percent_label(self) -> str:
        return f"{int(round(self.overall_fraction * 100))}%"
