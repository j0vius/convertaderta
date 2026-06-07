import XCTest
@testable import DjayPlaylistBridgeCore

final class CsvParserTests: XCTestCase {
    private let parser = DjayCsvParser()

    func testParsesLocalTracksFixture() throws {
        let url = fixtureURL(named: "local_tracks.csv")
        let tracks = try parser.parse(url: url)
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks[0].title, "Song One")
        XCTAssertEqual(tracks[0].artist, "Artist A")
        XCTAssertEqual(tracks[0].url, "file:///tmp/djay-test/song-one.mp3")
        XCTAssertEqual(tracks[1].bpm, "120.5")
    }

    func testParsesQuotedFieldsWithCommasAndAccents() throws {
        let url = fixtureURL(named: "quoted_fields.csv")
        let tracks = try parser.parse(url: url)
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks[0].title, "Track, With Comma")
        XCTAssertEqual(tracks[0].artist, "José García")
        XCTAssertEqual(tracks[0].album, "Álbum Especial")
    }

    func testParsesMixedTracksFixture() throws {
        let url = fixtureURL(named: "mixed_tracks.csv")
        let tracks = try parser.parse(url: url)
        XCTAssertEqual(tracks.count, 3)
        XCTAssertEqual(tracks[1].url, "apple-music://track/12345")
    }

    func testRejectsInvalidHeader() {
        XCTAssertThrowsError(try parser.parse(content: "Foo,Bar\nA,B")) { error in
            XCTAssertEqual(error as? DjayCsvParserError, .invalidHeader)
        }
    }

    private func fixtureURL(named name: String) -> URL {
        if let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "fixtures") {
            return url
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures")
            .appendingPathComponent(name)
    }
}
