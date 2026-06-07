import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var shouldOpenCSV = false
}
