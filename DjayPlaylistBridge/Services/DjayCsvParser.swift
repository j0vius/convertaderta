import Foundation

enum DjayCsvParserError: LocalizedError, Equatable {
    case emptyFile
    case invalidHeader
    case noTracks

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The CSV file is empty."
        case .invalidHeader:
            return "The CSV header does not match the expected djay Pro format."
        case .noTracks:
            return "No tracks were found in the CSV file."
        }
    }
}

struct DjayCsvParser {
    private static let expectedHeaders = ["Title", "Artist", "Album", "Time", "BPM", "Key", "URL"]

    func parse(url: URL) throws -> [DjayTrack] {
        var content = try String(contentsOf: url, encoding: .utf8)
        if content.hasPrefix("\u{FEFF}") {
            content.removeFirst()
        }
        return try parse(content: content)
    }

    func parse(content: String) throws -> [DjayTrack] {
        var normalized = content
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }
        let rows = parseRows(from: normalized)
        guard !rows.isEmpty else { throw DjayCsvParserError.emptyFile }

        let header = rows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard header.count >= 7,
              header[0].caseInsensitiveCompare("Title") == .orderedSame,
              header[6].caseInsensitiveCompare("URL") == .orderedSame else {
            throw DjayCsvParserError.invalidHeader
        }

        let dataRows = rows.dropFirst()
        let tracks = dataRows.compactMap { row -> DjayTrack? in
            guard row.count >= 7 else { return nil }
            let title = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty || !artist.isEmpty else { return nil }
            return DjayTrack(
                title: title,
                artist: artist,
                album: row[2].trimmingCharacters(in: .whitespacesAndNewlines),
                time: row[3].trimmingCharacters(in: .whitespacesAndNewlines),
                bpm: row[4].trimmingCharacters(in: .whitespacesAndNewlines),
                key: row[5].trimmingCharacters(in: .whitespacesAndNewlines),
                url: row[6].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        guard !tracks.isEmpty else { throw DjayCsvParserError.noTracks }
        return tracks
    }

    private func parseRows(from content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var index = content.startIndex

        while index < content.endIndex {
            let char = content[index]

            if inQuotes {
                if char == "\"" {
                    let next = content.index(after: index)
                    if next < content.endIndex, content[next] == "\"" {
                        currentField.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else if char == "," {
                currentRow.append(currentField)
                currentField = ""
            } else if char == "\n" {
                currentRow.append(currentField)
                currentField = ""
                if !currentRow.allSatisfy({ $0.isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow = []
            } else if char != "\r" {
                currentField.append(char)
            }

            index = content.index(after: index)
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }
}
