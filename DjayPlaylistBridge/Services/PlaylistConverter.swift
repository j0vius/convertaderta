import Foundation

struct PlaylistConverter {
    typealias ProgressHandler = (ConversionProgress) -> Void

    private let parser = DjayCsvParser()
    private let resolver = TrackResolver()
    private let writer = M3u8Writer()
    private let musicLookup = MusicTrackLookup()
    private var localIndex: LocalMusicIndex?
    var lastWarning: String?

    mutating func parseTracks(from csvURL: URL) throws -> [DjayTrack] {
        let tracks = try parser.parse(url: csvURL)
        return resolver.resolveAll(tracks)
    }

    mutating func resolveTracks(
        _ tracks: [DjayTrack],
        onProgress: ProgressHandler? = nil
    ) throws -> [DjayTrack] {
        lastWarning = nil

        if localIndex == nil {
            onProgress?(
                ConversionProgress(
                    phase: .scanningLocal,
                    current: 0,
                    total: 0,
                    detail: "Searching Documents/music folders for audio files…"
                )
            )
            localIndex = LocalMusicIndex.build { fileCount in
                onProgress?(
                    ConversionProgress(
                        phase: .scanningLocal,
                        current: fileCount,
                        total: 0,
                        detail: "Indexed \(fileCount) local audio files…"
                    )
                )
            }
        }

        let needsMusicLookup = tracks.filter {
            if case .musicLibrary = $0.resolution { return true }
            return false
        }
        var musicLookupIndex = 0

        return try tracks.map { track in
            if case .localFile = track.resolution {
                return track
            }

            guard case .musicLibrary = track.resolution else {
                return track
            }

            if let localIndex,
               let path = localIndex.findPath(title: track.title, artist: track.artist),
               FileManager.default.fileExists(atPath: path) {
                var resolved = track
                resolved.resolution = .localFile(path: path)
                return resolved
            }

            musicLookupIndex += 1
            onProgress?(
                ConversionProgress(
                    phase: .matchingMusic,
                    current: musicLookupIndex,
                    total: needsMusicLookup.count,
                    detail: "\(track.title) — \(track.artist)"
                )
            )

            do {
                if let path = try musicLookup.lookupPath(title: track.title, artist: track.artist),
                   FileManager.default.fileExists(atPath: path) {
                    var resolved = track
                    resolved.resolution = .localFile(path: path)
                    return resolved
                }
            } catch MusicTrackLookupError.accessDenied {
                lastWarning = MusicTrackLookupError.accessDenied.errorDescription
            } catch {
                lastWarning = error.localizedDescription
            }

            var missing = track
            missing.resolution = .missingFile(path: track.url)
            return missing
        }
    }

    mutating func convert(
        csvURL: URL,
        outputURL: URL? = nil,
        onProgress: ProgressHandler? = nil
    ) throws -> ConversionResult {
        onProgress?(
            ConversionProgress(
                phase: .preparing,
                current: 0,
                total: 0,
                detail: "Reading playlist from CSV…"
            )
        )

        var tracks = try parseTracks(from: csvURL)
        tracks = try resolveTracks(tracks, onProgress: onProgress)

        onProgress?(
            ConversionProgress(
                phase: .writing,
                current: 1,
                total: 1,
                detail: "Saving M3U8 file…"
            )
        )

        let destination = outputURL ?? writer.defaultOutputURL(for: csvURL)
        return try writer.write(tracks: tracks, to: destination)
    }
}
