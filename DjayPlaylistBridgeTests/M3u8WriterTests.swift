import XCTest
@testable import DjayPlaylistBridgeCore

final class M3u8WriterTests: XCTestCase {
    private var tempDir: URL!
    private let writer = M3u8Writer()

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("djay-m3u8-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testWritesExtendedM3u8() throws {
        let file = tempDir.appendingPathComponent("song.mp3")
        FileManager.default.createFile(atPath: file.path, contents: Data([0x00]))

        let tracks = [
            DjayTrack(
                title: "Song One",
                artist: "Artist A",
                album: "Album",
                time: "3:45",
                bpm: "128",
                key: "Am",
                url: "file://\(file.path)",
                resolution: .localFile(path: file.path)
            ),
            DjayTrack(
                title: "Missing",
                artist: "Artist B",
                album: "Album",
                time: "4:00",
                bpm: "120",
                key: "Cm",
                url: "file:///missing.mp3",
                resolution: .missingFile(path: "/missing.mp3")
            )
        ]

        let output = tempDir.appendingPathComponent("playlist.m3u8")
        let result = try writer.write(tracks: tracks, to: output)

        let content = try String(contentsOf: output, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("#EXTM3U\n"))
        XCTAssertTrue(content.contains("#EXTINF:225,Artist A - Song One"))
        XCTAssertTrue(content.contains(file.path))
        XCTAssertFalse(content.contains("/missing.mp3"))
        XCTAssertEqual(result.resolvedCount, 1)
        XCTAssertEqual(result.missingCount, 1)
    }

    func testThrowsWhenNoResolvableTracks() {
        let tracks = [
            DjayTrack(
                title: "Missing",
                artist: "Artist",
                album: "Album",
                time: "3:00",
                bpm: "120",
                key: "Am",
                url: "file:///missing.mp3",
                resolution: .missingFile(path: "/missing.mp3")
            )
        ]
        let output = tempDir.appendingPathComponent("empty.m3u8")
        XCTAssertThrowsError(try writer.write(tracks: tracks, to: output)) { error in
            XCTAssertEqual(error as? M3u8WriterError, .noResolvableTracks)
        }
    }
}
