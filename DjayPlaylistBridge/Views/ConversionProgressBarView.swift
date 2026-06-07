import SwiftUI

struct ConversionProgressBarView: View {
    let progress: ConversionProgress

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label(progress.phaseTitle, systemImage: phaseIcon)
                        .font(.headline)
                    Spacer()
                    Text(progress.percentLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let counter = progress.counterLabel {
                        Text(counter)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: progress.overallFraction)
                    .progressViewStyle(.linear)

                Text(progress.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeInOut(duration: 0.25), value: progress)
    }

    private var phaseIcon: String {
        switch progress.phase {
        case .preparing:
            return "doc.text"
        case .scanningLocal:
            return "folder"
        case .matchingMusic:
            return "music.note"
        case .writing:
            return "square.and.arrow.down"
        case .importingToMusic:
            return "music.note.list"
        }
    }
}
