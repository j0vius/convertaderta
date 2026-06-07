import Foundation

enum MusicTrackLookupError: LocalizedError {
    case accessDenied
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return """
            Allow convertaderta to control Music:
            System Settings → Privacy & Security → Automation → enable Music for convertaderta.
            Then quit and reopen the app.
            """
        case .scriptFailed(let detail):
            return detail
        }
    }
}

struct MusicTrackLookup {
    func lookupPath(title: String, artist: String) throws -> String? {
        let primaryArtist = artist
            .split(separator: ",")
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? artist
        let query = escapeForAppleScript("\(title) \(primaryArtist)")
        let escapedTitle = escapeForAppleScript(title)
        let escapedArtist = escapeForAppleScript(primaryArtist)

        let script = """
        tell application "Music"
            set foundTracks to (search library playlist 1 for "\(query)" only songs)
            repeat with t in foundTracks
                if name of t contains "\(escapedTitle)" and artist of t contains "\(escapedArtist)" then
                    try
                        return POSIX path of ((location of t) as alias)
                    end try
                end if
            end repeat
            if (count of foundTracks) > 0 then
                set t to item 1 of foundTracks
                try
                    return POSIX path of ((location of t) as alias)
                end try
            end if
            return ""
        end tell
        """

        let output = try runOsascript(script, timeout: 15)
        return output.isEmpty ? nil : output
    }

    private func escapeForAppleScript(_ value: String) -> String {
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
            throw MusicTrackLookupError.scriptFailed("Timed out looking up track in Music.")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            if errorOutput.localizedCaseInsensitiveContains("not authorized")
                || errorOutput.contains("-1743") {
                throw MusicTrackLookupError.accessDenied
            }
            throw MusicTrackLookupError.scriptFailed(
                errorOutput.isEmpty ? "Could not query Music for this track." : errorOutput
            )
        }

        return output
    }
}
