import SwiftUI

struct ResultsView: View {
    let result: ConversionResult
    let onReveal: () -> Void
    let onImportToMusic: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Conversion complete") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.summary)
                        .font(.headline)
                    Text("Saved to \(result.outputURL.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    HStack {
                        Button("Reveal in Finder", action: onReveal)
                        Button("Import to Apple Music", action: onImportToMusic)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Next step in djay Pro") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Convert CSV to M3U8", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("Import into Apple Music", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("Drag the playlist from Music into djay My Collection", systemImage: "hand.point.right.fill")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
