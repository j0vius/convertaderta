import Foundation

struct LocalMusicIndex {
    struct Entry {
        let fileName: String
        let normalizedFileName: String
        let path: String
    }

    let entries: [Entry]

    func findPath(title: String, artist: String) -> String? {
        let normalizedTitle = Self.normalize(title)
        let artistVariants = Self.artistVariants(from: artist)
        let titleTokens = significantTokens(from: normalizedTitle)

        guard !titleTokens.isEmpty else { return nil }

        for primaryArtist in artistVariants {
            let normalizedArtist = Self.normalize(primaryArtist)
            let candidates = entries.filter { entry in
                let name = entry.normalizedFileName
                let titleMatches = titleTokens.allSatisfy { name.contains($0) }
                let artistMatches = normalizedArtist.isEmpty
                    || name.contains(normalizedArtist)
                    || normalizedArtist.split(separator: " ", omittingEmptySubsequences: true).allSatisfy { token in
                        token.count > 2 && name.contains(token)
                    }
                return titleMatches && artistMatches
            }

            if candidates.count == 1 {
                return candidates[0].path
            }

            if let best = candidates.max(by: {
                score($0, title: normalizedTitle, artist: normalizedArtist) < score($1, title: normalizedTitle, artist: normalizedArtist)
            }) {
                return best.path
            }
        }

        return nil
    }

    private static func artistVariants(from artist: String) -> [String] {
        var variants = [artist]
        variants.append(contentsOf: artist.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
        variants.append(contentsOf: artist.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) })
        return Array(Set(variants.filter { !$0.isEmpty }))
    }

    static func build(
        extraRoots: [URL] = [],
        onFileIndexed: ((Int) -> Void)? = nil
    ) -> LocalMusicIndex {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        var roots = [
            home.appendingPathComponent("Documents/music /Djay"),
            home.appendingPathComponent("Documents/music"),
        ]
        roots.append(contentsOf: extraRoots)

        var seenPaths = Set<String>()
        var collected: [Entry] = []
        let extensions = ["mp3", "flac", "wav", "m4a", "aiff", "aif", "aac"]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard extensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                let path = fileURL.path
                guard seenPaths.insert(path).inserted else { continue }
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                collected.append(
                    Entry(
                        fileName: fileName,
                        normalizedFileName: Self.normalize(fileName),
                        path: path
                    )
                )
                if collected.count % 25 == 0 {
                    onFileIndexed?(collected.count)
                }
            }
        }

        if !collected.isEmpty {
            onFileIndexed?(collected.count)
        }

        return LocalMusicIndex(entries: collected)
    }

    private func score(_ entry: Entry, title: String, artist: String) -> Int {
        var value = 0
        if entry.normalizedFileName.contains(title) { value += 10 }
        if !artist.isEmpty, entry.normalizedFileName.contains(artist) { value += 5 }
        return value
    }

    private static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "@", with: "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
    }

    private func significantTokens(from normalizedTitle: String) -> [String] {
        let stripped = normalizedTitle
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "'", with: " ")

        return stripped
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { $0.count > 2 }
            .prefix(4)
            .map { String($0) }
    }
}
