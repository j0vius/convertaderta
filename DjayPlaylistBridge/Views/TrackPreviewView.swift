import SwiftUI

struct TrackPreviewView: View {
    let tracks: [DjayTrack]

    var body: some View {
        Table(tracks) {
            TableColumn("Title") { track in
                Text(track.title)
            }
            TableColumn("Artist") { track in
                Text(track.artist)
            }
            TableColumn("Status") { track in
                StatusBadge(resolution: track.resolution)
            }
        }
    }
}

private struct StatusBadge: View {
    let resolution: TrackResolution

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch resolution {
        case .localFile: return "Resolved"
        case .missingFile: return "Missing"
        case .musicLibrary: return "Pending"
        }
    }

    private var color: Color {
        switch resolution {
        case .localFile: return .green
        case .missingFile: return .orange
        case .musicLibrary: return .yellow
        }
    }
}
