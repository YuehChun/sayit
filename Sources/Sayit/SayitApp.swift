import SwiftUI

@main
struct SayitApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra("Sayit", systemImage: "mic.fill") {
            MenuBarView(appState: appState, openSettings: openSettings)
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}
