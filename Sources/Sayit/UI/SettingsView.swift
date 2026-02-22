import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var geminiKey: String = ""
    @State private var geminiSaved = false
    @State private var geminiError = false
    @State private var openRouterKey: String = ""
    @State private var openRouterSaved = false
    @State private var openRouterError = false

    private let keychainManager = KeychainManager()

    var body: some View {
        Form {
            Section("API Keys") {
                // Gemini
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gemini API Key")
                        .font(.headline)
                    Text("Cloud STT provider (gemini-2.5-flash-lite)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        SecureField("Enter Gemini API Key", text: $geminiKey)
                            .textFieldStyle(.roundedBorder)
                        Button(geminiSaved ? "Saved" : (geminiError ? "Failed" : "Save")) {
                            geminiError = false
                            if keychainManager.save(key: geminiKey, for: .geminiAPIKey) {
                                geminiSaved = true
                                geminiKey = ""
                            } else {
                                geminiError = true
                            }
                        }
                        .disabled(geminiKey.isEmpty)
                        .foregroundColor(geminiError ? .red : nil)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: keychainManager.hasKey(.geminiAPIKey) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(keychainManager.hasKey(.geminiAPIKey) ? .green : .red)
                        Text(keychainManager.hasKey(.geminiAPIKey) ? "Key configured" : "Not configured (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // OpenRouter
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenRouter API Key")
                        .font(.headline)
                    Text("Fallback when Gemini quota exceeded (google/gemini-2.5-flash)")
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
        .onChange(of: geminiSaved) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    geminiSaved = false
                }
            }
        }
        .onChange(of: openRouterSaved) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    openRouterSaved = false
                }
            }
        }
    }
}
