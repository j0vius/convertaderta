import tempfile
import unittest
from pathlib import Path

from convertaderta.csv_parser import DjayCsvParser
from convertaderta.m3u8_writer import M3u8Writer
from convertaderta.models import DjayTrack, TrackResolution
from convertaderta.track_resolver import TrackResolver


FIXTURES = Path(__file__).resolve().parents[2] / "DjayPlaylistBridgeTests" / "fixtures"


class CoreTests(unittest.TestCase):
    def test_parse_ipod_library_csv(self) -> None:
        content = (FIXTURES / "ipod_library.csv").read_text(encoding="utf-8")
        tracks = DjayCsvParser().parse_content(content)
        self.assertEqual(len(tracks), 1)
        self.assertEqual(tracks[0].title, "LOVE DESIRE (Extended Mix)")

    def test_resolve_ipod_library_url(self) -> None:
        track = DjayTrack(
            title="Song",
            artist="Artist",
            album="",
            time="03:00",
            bpm="",
            key="",
            url="ipod-library://item/item.mp3?id=123",
        )
        resolved = TrackResolver().resolve(track)
        self.assertEqual(resolved.resolution, TrackResolution.MUSIC_LIBRARY)

    def test_write_m3u8(self) -> None:
        tracks = [
            DjayTrack(
                title="Song",
                artist="Artist",
                album="",
                time="03:30",
                bpm="",
                key="",
                url="file:///tmp/song.mp3",
                resolution=TrackResolution.LOCAL_FILE,
                resolved_path="/tmp/song.mp3",
            )
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "convertaderta-test.m3u8"
            result = M3u8Writer().write(tracks, str(output))
            self.assertEqual(result.resolved_count, 1)
            body = output.read_text(encoding="utf-8")
            self.assertIn("#EXTM3U", body)
            self.assertIn("/tmp/song.mp3", body)


if __name__ == "__main__":
    unittest.main()
