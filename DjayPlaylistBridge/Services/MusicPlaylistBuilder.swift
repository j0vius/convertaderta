import Foundation
import AppKit

enum MusicPlaylistBuilderError: LocalizedError {
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .importFailed(let detail):
            return "Failed to import playlist into Music: \(detail)"
        }
    }
}

struct MusicPlaylistBuilder {
    func importPlaylist(at url: URL) throws {
        let escapedPath = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Music"
            activate
            import POSIX file "\(escapedPath)"
        end tell
        """
        try runAppleScript(script)
    }

    private func runAppleScript(_ source: String) throws {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw MusicPlaylistBuilderError.importFailed("Could not create AppleScript.")
        }
        script.executeAndReturnError(&error)
        if let error {
            throw MusicPlaylistBuilderError.importFailed(error.description)
        }
    }
}
