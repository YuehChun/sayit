import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    var openSettings: OpenSettingsAction

    var body: some View {
        VStack {
            Text("Sayit")
                .font(.headline)

            Divider()

            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.recordingState.statusText)
                    .font(.caption)
            }

            Divider()

            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Sayit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .onAppear {
            appState.setupServices()
        }
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle: return .gray
        case .recording: return .red
        case .processing: return .orange
        case .injecting: return .green
        case .error: return .red
        }
    }
}
