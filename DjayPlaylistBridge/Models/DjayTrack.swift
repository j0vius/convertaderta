import Foundation

enum TrackResolution: Equatable {
    case localFile(path: String)
    case missingFile(path: String)
    case musicLibrary(libraryID: String)
}

struct DjayTrack: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let time: String
    let bpm: String
    let key: String
    let url: String
    var resolution: TrackResolution

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        time: String,
        bpm: String,
        key: String,
        url: String,
        resolution: TrackResolution = .musicLibrary(libraryID: "")
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.time = time
        self.bpm = bpm
        self.key = key
        self.url = url
        self.resolution = resolution
    }

    var statusLabel: String {
        switch resolution {
        case .localFile:
            return "Resolved"
        case .missingFile:
            return "Missing"
        case .musicLibrary:
            return "Looking up…"
        }
    }

    var durationSeconds: Int? {
        DurationParser.seconds(from: time)
    }
}
