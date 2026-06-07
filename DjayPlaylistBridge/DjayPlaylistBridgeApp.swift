import SwiftUI

@main
struct DjayPlaylistBridgeApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("File") {
                Button("Open CSV…") {
                    appModel.shouldOpenCSV = true
                }
                .keyboardShortcut("o")
            }
        }
    }
}
