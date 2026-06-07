import Foundation

struct TrackResolver {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func resolve(_ track: DjayTrack) -> DjayTrack {
        var updated = track
        updated.resolution = resolveUrl(track.url)
        return updated
    }

    func resolveAll(_ tracks: [DjayTrack]) -> [DjayTrack] {
        tracks.map(resolve)
    }

    func resolveUrl(_ urlString: String) -> TrackResolution {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .missingFile(path: "") }

        let lowercased = trimmed.lowercased()

        if lowercased.hasPrefix("ipod-library://") {
            let libraryID = extractLibraryID(from: trimmed) ?? trimmed
            return .musicLibrary(libraryID: libraryID)
        }

        if lowercased.hasPrefix("file://") {
            return resolveFilePath(extractFilePath(from: trimmed))
        }

        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            let expanded = (trimmed as NSString).expandingTildeInPath
            return resolveFilePath(expanded)
        }

        return .missingFile(path: trimmed)
    }

    private func resolveFilePath(_ path: String) -> TrackResolution {
        guard !path.isEmpty else { return .missingFile(path: path) }
        if fileManager.fileExists(atPath: path) {
            return .localFile(path: path)
        }
        return .missingFile(path: path)
    }

    private func extractFilePath(from urlString: String) -> String {
        if let url = URL(string: urlString), url.isFileURL {
            return url.path
        }

        var path = String(urlString.dropFirst("file://".count))
        if path.hasPrefix("localhost") {
            path = String(path.dropFirst("localhost".count))
        }
        path = path.removingPercentEncoding ?? path
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        return (path as NSString).standardizingPath
    }

    private func extractLibraryID(from urlString: String) -> String? {
        guard let components = URLComponents(string: urlString) else { return nil }
        return components.queryItems?.first(where: { $0.name == "id" })?.value
    }
}
