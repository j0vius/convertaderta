import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var csvURL: URL?
    @State private var tracks: [DjayTrack] = []
    @State private var conversionResult: ConversionResult?
    @State private var isConverting = false
    @State private var conversionProgress: ConversionProgress?
    @State private var errorMessage: String?
    @State private var converter = PlaylistConverter()

    private let musicBuilder = MusicPlaylistBuilder()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if csvURL == nil {
                DropZoneView(onFileDropped: loadCSV)
            } else {
                fileInfo
            }

            if let conversionProgress {
                ConversionProgressBarView(progress: conversionProgress)
            }

            if !tracks.isEmpty {
                TrackPreviewView(tracks: tracks)
                    .frame(minHeight: 220)
            }

            if let conversionResult {
                ResultsView(
                    result: conversionResult,
                    onReveal: { revealInFinder(conversionResult.outputURL) },
                    onImportToMusic: { importToMusic(conversionResult.outputURL) }
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            footer
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
        .onChange(of: appModel.shouldOpenCSV) { shouldOpen in
            if shouldOpen {
                openCSV()
                appModel.shouldOpenCSV = false
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("AppMascot")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("convertaderta")
                    .font(.largeTitle.bold())
                Text("Convert djay Pro CSV playlists to M3U8 for local music files.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fileInfo: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(csvURL?.lastPathComponent ?? "")
                    .font(.headline)
                Text("\(tracks.count) tracks loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open CSV…") { openCSV() }
            Button("Convert") { convert() }
                .buttonStyle(.borderedProminent)
                .disabled(isConverting || tracks.isEmpty)
        }
    }

    private var footer: some View {
        HStack {
            Text("Matches playlist tracks against your Music library.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    func openCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText, UTType(filenameExtension: "csv")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadCSV(url)
    }

    func loadCSV(_ url: URL) {
        errorMessage = nil
        conversionProgress = nil
        conversionResult = nil
        csvURL = url

        do {
            tracks = try converter.parseTracks(from: url)
        } catch {
            tracks = []
            errorMessage = error.localizedDescription
        }
    }

    func convert() {
        guard let csvURL else { return }
        isConverting = true
        errorMessage = nil
        conversionProgress = ConversionProgress(
            phase: .preparing,
            current: 0,
            total: 0,
            detail: "Starting conversion…"
        )

        var localConverter = converter

        Task.detached {
            do {
                let result = try localConverter.convert(csvURL: csvURL) { progress in
                    Task { @MainActor in
                        conversionProgress = progress
                    }
                }

                await MainActor.run {
                    converter = localConverter
                    conversionResult = result
                    tracks = result.tracks
                    conversionProgress = nil
                    isConverting = false
                    if let warning = localConverter.lastWarning {
                        errorMessage = warning
                    }
                }
            } catch {
                await MainActor.run {
                    conversionProgress = nil
                    isConverting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func importToMusic(_ url: URL) {
        errorMessage = nil
        isConverting = true
        conversionProgress = ConversionProgress(
            phase: .importingToMusic,
            current: 0,
            total: 0,
            detail: "Adding tracks to a new playlist in Music…"
        )

        let builder = musicBuilder

        Task.detached {
            do {
                try builder.importPlaylist(at: url)
                await MainActor.run {
                    conversionProgress = nil
                    isConverting = false
                }
            } catch {
                await MainActor.run {
                    conversionProgress = nil
                    isConverting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
