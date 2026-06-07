import XCTest
@testable import DjayPlaylistBridgeCore

final class TrackResolverTests: XCTestCase {
    private var tempDir: URL!
    private var resolver: TrackResolver!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("djay-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        resolver = TrackResolver(fileManager: .default)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testResolvesExistingLocalFile() throws {
        let file = tempDir.appendingPathComponent("track.mp3")
        FileManager.default.createFile(atPath: file.path, contents: Data([0x00]))

        let encoded = "file://\(file.path)"
        let resolution = resolver.resolveUrl(encoded)
        XCTAssertEqual(resolution, .localFile(path: file.path))
    }

    func testDetectsMissingFile() {
        let resolution = resolver.resolveUrl("file:///tmp/djay-test/does-not-exist.mp3")
        XCTAssertEqual(resolution, .missingFile(path: "/tmp/djay-test/does-not-exist.mp3"))
    }

    func testUnknownURLMarkedMissing() {
        let resolution = resolver.resolveUrl("apple-music://track/12345")
        if case .missingFile = resolution {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected missingFile")
        }
    }

    func testDetectsIpodLibraryURL() {
        let resolution = resolver.resolveUrl("ipod-library://item/item.mp3?id=3199836266511111566")
        XCTAssertEqual(resolution, .musicLibrary(libraryID: "3199836266511111566"))
    }

    func testParsesIpodLibraryFixture() throws {
        let url = fixtureURL(named: "ipod_library.csv")
        let tracks = try DjayCsvParser().parse(url: url)
        XCTAssertEqual(tracks.count, 1)
        let resolved = resolver.resolve(tracks[0])
        XCTAssertEqual(
            resolved.resolution,
            .musicLibrary(libraryID: "3199836266511111566")
        )
    }

    private func fixtureURL(named name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures")
            .appendingPathComponent(name)
    }

    func testDecodesPercentEncodedPaths() throws {
        let folder = tempDir.appendingPathComponent("My Music", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("track one.mp3")
        FileManager.default.createFile(atPath: file.path, contents: Data([0x00]))

        let encodedPath = file.path.replacingOccurrences(of: " ", with: "%20")
        let resolution = resolver.resolveUrl("file://\(encodedPath)")
        XCTAssertEqual(resolution, .localFile(path: file.path))
    }

    func testParsesDuration() {
        XCTAssertEqual(DurationParser.seconds(from: "3:45"), 225)
        XCTAssertEqual(DurationParser.seconds(from: "1:02:03"), 3723)
        XCTAssertNil(DurationParser.seconds(from: ""))
    }
}
