import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var openRouterKey: String = ""
    @State private var openRouterSaved = false
    @State private var openRouterError = false
    @State private var claudeKey: String = ""
    @State private var claudeSaved = false
    @State private var claudeError = false

    private let keychainManager = KeychainManager()

    var body: some View {
        Form {
            Section("API Keys") {
                // OpenRouter
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenRouter API Key")
                        .font(.headline)
                    Text("Used as cloud STT fallback (google/gemini-2.5-flash)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        SecureField("Enter OpenRouter API Key", text: $openRouterKey)
                            .textFieldStyle(.roundedBorder)
                        Button(openRouterSaved ? "Saved" : (openRouterError ? "Failed" : "Save")) {
                            openRouterError = false
                            if keychainManager.save(key: openRouterKey, for: .openRouterAPIKey) {
                                openRouterSaved = true
                                openRouterKey = ""
                            } else {
                                openRouterError = true
                            }
                        }
                        .disabled(openRouterKey.isEmpty)
                        .foregroundColor(openRouterError ? .red : nil)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: keychainManager.hasKey(.openRouterAPIKey) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(keychainManager.hasKey(.openRouterAPIKey) ? .green : .red)
                        Text(keychainManager.hasKey(.openRouterAPIKey) ? "Key configured" : "Not configured (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Claude
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude API Key")
                        .font(.headline)
                    HStack {
                        SecureField("Enter Claude API Key", text: $claudeKey)
                            .textFieldStyle(.roundedBorder)
                        Button(claudeSaved ? "Saved" : (claudeError ? "Failed" : "Save")) {
                            claudeError = false
                            if keychainManager.save(key: claudeKey, for: .claudeAPIKey) {
                                claudeSaved = true
                                claudeKey = ""
                            } else {
                                claudeError = true
                            }
                        }
                        .disabled(claudeKey.isEmpty)
                        .foregroundColor(claudeError ? .red : nil)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: keychainManager.hasKey(.claudeAPIKey) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(keychainManager.hasKey(.claudeAPIKey) ? .green : .red)
                        Text(keychainManager.hasKey(.claudeAPIKey) ? "Key configured" : "Not configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Permissions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Required Permissions")
                        .font(.headline)
                    Text("Sayit needs the following permissions to work:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("Microphone Access", systemImage: "mic.fill")
                    Label("Speech Recognition", systemImage: "waveform")
                    Label("Accessibility (for global shortcuts & text injection)", systemImage: "lock.shield")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 420)
        .onChange(of: openRouterSaved) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    openRouterSaved = false
                }
            }
        }
        .onChange(of: claudeSaved) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    claudeSaved = false
                }
            }
        }
    }
}
