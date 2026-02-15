import Foundation

@MainActor
final class PipelineOrchestrator {
    private let audioCaptureManager: AudioCaptureManager
    private let geminiSTTService: GeminiSTTService
    private let openRouterSTTService: OpenRouterSTTService
    private let keychainManager: KeychainManager
    private let textInjectionService: TextInjectionService
    private weak var appState: AppState?
    private var errorDismissTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?

    /// Minimum PCM audio bytes required (0.5s at 8kHz, 16-bit mono = 8000 bytes)
    private let minimumAudioBytes = 8000

    init(
        audioCaptureManager: AudioCaptureManager,
        geminiSTTService: GeminiSTTService,
        openRouterSTTService: OpenRouterSTTService,
        keychainManager: KeychainManager,
        textInjectionService: TextInjectionService,
        appState: AppState
    ) {
        self.audioCaptureManager = audioCaptureManager
        self.geminiSTTService = geminiSTTService
        self.openRouterSTTService = openRouterSTTService
        self.keychainManager = keychainManager
        self.textInjectionService = textInjectionService
        self.appState = appState
    }

    func startRecording() {
        guard let appState = appState else { return }

        // Cancel any in-flight processing from previous recording
        processingTask?.cancel()
        processingTask = nil

        // Cancel any pending error dismiss
        errorDismissTask?.cancel()
        errorDismissTask = nil

        do {
            try audioCaptureManager.startRecording()
            appState.recordingState = .recording
            appState.rawTranscript = ""
            appState.refinedText = ""
            appState.showFloatingPanel = true
            appState.floatingPanelController?.showPanel()
        } catch {
            appState.recordingState = .error(error.localizedDescription)
        }
    }

    func stopRecordingAndProcess() async {
        guard let appState = appState else { return }

        let wavData = audioCaptureManager.stopRecording()

        // WAV header is 44 bytes; check actual audio content meets minimum duration
        let pcmBytes = wavData.count - 44
        guard pcmBytes >= minimumAudioBytes else {
            NSLog("[Sayit] Pipeline: Audio too short (%d PCM bytes, min %d), skipping API call", pcmBytes, minimumAudioBytes)
            appState.recordingState = .idle
            appState.showFloatingPanel = false
            appState.floatingPanelController?.hidePanel()
            return
        }

        appState.recordingState = .processing
        NSLog("[Sayit] Pipeline: WAV data size = %d bytes (%.1fs audio)", wavData.count, Double(pcmBytes) / 16000.0)

        // Wrap processing in a cancellable task
        processingTask?.cancel()
        processingTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                // Step 1: Speech to text + refinement
                // Prefer Gemini if API key is configured, otherwise fall back to OpenRouter
                let result: String
                if self.keychainManager.hasKey(.geminiAPIKey) {
                    NSLog("[Sayit] Pipeline: Starting Gemini STT+Refine...")
                    result = try await self.geminiSTTService.transcribe(wavData: wavData)
                } else {
                    NSLog("[Sayit] Pipeline: Starting OpenRouter STT+Refine...")
                    result = try await self.openRouterSTTService.transcribe(wavData: wavData)
                }

                // Check cancellation after API call
                try Task.checkCancellation()

                // Re-check appState after await
                guard let appState = self.appState else { return }

                NSLog("[Sayit] Pipeline: Result = %@", result)
                appState.refinedText = result

                // Step 2: Inject text
                appState.recordingState = .injecting
                appState.floatingPanelController?.hidePanel()

                // Small delay to let panel hide and target app regain focus
                try await Task.sleep(for: .milliseconds(100))
                try Task.checkCancellation()

                NSLog("[Sayit] Pipeline: Injecting text...")
                await self.textInjectionService.inject(text: result)

                // Re-check appState after await
                guard let appState = self.appState else { return }

                appState.recordingState = .idle
                appState.showFloatingPanel = false
                NSLog("[Sayit] Pipeline: Complete!")
            } catch is CancellationError {
                NSLog("[Sayit] Pipeline: Processing cancelled (new recording started)")
            } catch {
                NSLog("[Sayit] Pipeline ERROR: %@", error.localizedDescription)
                guard let appState = self.appState else { return }
                appState.recordingState = .error(error.localizedDescription)

                // Auto-dismiss error after 3 seconds (cancellable)
                self.errorDismissTask?.cancel()
                self.errorDismissTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    guard let appState = self?.appState else { return }
                    if case .error = appState.recordingState {
                        appState.recordingState = .idle
                        appState.showFloatingPanel = false
                        appState.floatingPanelController?.hidePanel()
                    }
                }
            }
        }
    }
}
