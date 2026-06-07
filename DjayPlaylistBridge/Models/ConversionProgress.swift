import Foundation

struct ConversionProgress: Equatable {
    enum Phase: Equatable {
        case preparing
        case scanningLocal
        case matchingMusic
        case writing
        case importingToMusic
    }

    let phase: Phase
    let current: Int
    let total: Int
    let detail: String

    var phaseTitle: String {
        switch phase {
        case .preparing:
            return "Preparing"
        case .scanningLocal:
            return "Scanning local music"
        case .matchingMusic:
            return "Matching in Apple Music"
        case .writing:
            return "Writing playlist"
        case .importingToMusic:
            return "Importing to Apple Music"
        }
    }

    var counterLabel: String? {
        switch phase {
        case .preparing:
            return nil
        case .scanningLocal:
            return current > 0 ? "\(current) files indexed" : nil
        case .matchingMusic:
            guard total > 0 else { return nil }
            return "\(current) of \(total)"
        case .writing, .importingToMusic:
            return nil
        }
    }

    var overallFraction: Double {
        switch phase {
        case .preparing:
            return 0.03
        case .scanningLocal:
            let scanCap = min(Double(current) / 1200.0, 1.0)
            return 0.05 + scanCap * 0.25
        case .matchingMusic:
            guard total > 0 else { return 0.35 }
            return 0.30 + (Double(current) / Double(total)) * 0.65
        case .writing:
            return 0.98
        case .importingToMusic:
            return 0.5
        }
    }

    var percentLabel: String {
        "\(Int((overallFraction * 100).rounded()))%"
    }
}
