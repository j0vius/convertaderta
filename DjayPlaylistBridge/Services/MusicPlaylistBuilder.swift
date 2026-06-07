import Foundation

enum MusicPlaylistBuilderError: LocalizedError {
    case importFailed(String)
    case noTracksInPlaylist
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .importFailed(let detail):
            return "Failed to import playlist into Music: \(detail)"
        case .noTracksInPlaylist:
            return "The M3U8 file contains no playable file paths."
        case .accessDenied:
            return """
            Allow DjayPlaylistBridge to control Music:
            System Settings → Privacy & Security → Automation → enable Music for DjayPlaylistBridge.
            Then quit and reopen the app.
            """
        }
    }
}

struct MusicPlaylistBuilder {
    func importPlaylist(at url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let paths = Self.parseFilePaths(from: content)
        guard !paths.isEmpty else { throw MusicPlaylistBuilderError.noTracksInPlaylist }

        let playlistName = Self.escapeForAppleScript(url.deletingPathExtension().lastPathComponent)
        var added = 0

        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let escapedPath = Self.escapeForAppleScript(path)
            let script = """
            tell application "Music"
                set playlistName to "\(playlistName)"
                if not (exists playlist playlistName) then
                    make new playlist with properties {name:playlistName}
                end if
                set targetPlaylist to playlist playlistName
                set trackFile to POSIX file "\(escapedPath)"
                add trackFile to targetPlaylist
            end tell
            """
            do {
                _ = try runOsascript(script, timeout: 20)
                added += 1
            } catch MusicPlaylistBuilderError.accessDenied {
                throw MusicPlaylistBuilderError.accessDenied
            } catch {
                continue
            }
        }

        guard added > 0 else {
            throw MusicPlaylistBuilderError.importFailed(
                "No tracks could be added. Check that files still exist at the paths in the M3U8."
            )
        }

        let activateScript = """
        tell application "Music"
            activate
            set playlistName to "\(playlistName)"
            if exists playlist playlistName then
                reveal playlist playlistName
            end if
        end tell
        """
        try? runOsascript(activateScript, timeout: 10)
    }

    private static func parseFilePaths(from m3uContent: String) -> [String] {
        m3uContent
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.hasPrefix("#") && !$0.isEmpty }
    }

    private static func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func runOsascript(_ source: String, timeout: TimeInterval) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            throw MusicPlaylistBuilderError.importFailed("Timed out talking to Music.")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            if errorOutput.localizedCaseInsensitiveContains("not authorized")
                || errorOutput.contains("-1743") {
                throw MusicPlaylistBuilderError.accessDenied
            }
            throw MusicPlaylistBuilderError.importFailed(
                errorOutput.isEmpty ? "Music returned an error." : errorOutput
            )
        }

        return output
    }
}
