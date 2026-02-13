import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var geminiKey: String = ""
    @State private var claudeKey: String = ""
    @State private var geminiSaved = false
    @State private var claudeSaved = false

    private let keychainManager = KeychainManager()

    var body: some View {
        Form {
            Section("API Keys") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gemini API Key")
                        .font(.headline)
                    HStack {
                        SecureField("Enter Gemini API Key", text: $geminiKey)
                            .textFieldStyle(.roundedBorder)
                        Button(geminiSaved ? "Saved" : "Save") {
                            if keychainManager.save(key: geminiKey, for: .geminiAPIKey) {
                                geminiSaved = true
                                geminiKey = ""
                            }
                        }
                        .disabled(geminiKey.isEmpty)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: keychainManager.hasKey(.geminiAPIKey) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(keychainManager.hasKey(.geminiAPIKey) ? .green : .red)
                        Text(keychainManager.hasKey(.geminiAPIKey) ? "Key configured" : "Not configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude API Key")
                        .font(.headline)
                    HStack {
                        SecureField("Enter Claude API Key", text: $claudeKey)
                            .textFieldStyle(.roundedBorder)
                        Button(claudeSaved ? "Saved" : "Save") {
                            if keychainManager.save(key: claudeKey, for: .claudeAPIKey) {
                                claudeSaved = true
                                claudeKey = ""
                            }
                        }
                        .disabled(claudeKey.isEmpty)
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
                    Label("Accessibility (for global shortcuts & text injection)", systemImage: "lock.shield")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 380)
        .onChange(of: geminiSaved) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    geminiSaved = false
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
