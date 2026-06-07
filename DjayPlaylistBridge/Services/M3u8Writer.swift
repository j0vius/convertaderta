import Foundation

enum M3u8WriterError: LocalizedError, Equatable {
    case noResolvableTracks

    var errorDescription: String? {
        switch self {
        case .noResolvableTracks:
            return "No local files were found. Make sure tracks exist in your Music library with files on disk."
        }
    }
}

struct M3u8Writer {
    func write(tracks: [DjayTrack], to outputURL: URL) throws -> ConversionResult {
        let localTracks = tracks.compactMap { track -> (DjayTrack, String)? in
            guard case .localFile(let path) = track.resolution else { return nil }
            return (track, path)
        }

        guard !localTracks.isEmpty else { throw M3u8WriterError.noResolvableTracks }

        var lines = ["#EXTM3U"]
        for (track, path) in localTracks {
            let duration = track.durationSeconds ?? -1
            let label = "\(track.artist) - \(track.title)"
            lines.append("#EXTINF:\(duration),\(label)")
            lines.append(path)
        }

        let body = lines.joined(separator: "\n") + "\n"
        try body.write(to: outputURL, atomically: true, encoding: .utf8)

        let resolved = tracks.filter {
            if case .localFile = $0.resolution { return true }
            return false
        }.count
        let missing = tracks.count - resolved

        return ConversionResult(
            playlistName: outputURL.deletingPathExtension().lastPathComponent,
            outputURL: outputURL,
            tracks: tracks,
            resolvedCount: resolved,
            missingCount: missing
        )
    }

    func defaultOutputURL(for csvURL: URL) -> URL {
        csvURL.deletingPathExtension().appendingPathExtension("m3u8")
    }
}
