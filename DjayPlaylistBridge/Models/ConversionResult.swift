import Foundation

struct ConversionResult: Equatable {
    let playlistName: String
    let outputURL: URL
    let tracks: [DjayTrack]
    let resolvedCount: Int
    let missingCount: Int

    var summary: String {
        var parts = ["\(resolvedCount) resolved"]
        if missingCount > 0 { parts.append("\(missingCount) missing") }
        return parts.joined(separator: ", ")
    }
}
