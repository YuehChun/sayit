import Foundation

@MainActor
final class PipelineOrchestrator {
    private let audioCaptureManager: AudioCaptureManager
    private let geminiSTTService: GeminiSTTService
    private let textInjectionService: TextInjectionService
    private weak var appState: AppState?
    private var errorDismissTask: Task<Void, Never>?

    init(
        audioCaptureManager: AudioCaptureManager,
        geminiSTTService: GeminiSTTService,
        textInjectionService: TextInjectionService,
        appState: AppState
    ) {
        self.audioCaptureManager = audioCaptureManager
        self.geminiSTTService = geminiSTTService
        self.textInjectionService = textInjectionService
        self.appState = appState
    }

    func startRecording() {
        guard let appState = appState else { return }

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

        guard !wavData.isEmpty else {
            appState.recordingState = .error("No audio recorded")
            return
        }

        appState.recordingState = .processing
        NSLog("[Sayit] Pipeline: WAV data size = %d bytes", wavData.count)

        do {
            // Step 1: Speech to text + refinement (single API call)
            NSLog("[Sayit] Pipeline: Starting Gemini STT+Refine...")
            let result = try await geminiSTTService.transcribe(wavData: wavData)

            // Re-check appState after await
            guard let appState = self.appState else { return }

            NSLog("[Sayit] Pipeline: Result = %@", result)
            appState.refinedText = result

            // Step 2: Inject text
            appState.recordingState = .injecting
            appState.floatingPanelController?.hidePanel()

            // Small delay to let panel hide and target app regain focus
            try await Task.sleep(for: .milliseconds(100))

            NSLog("[Sayit] Pipeline: Injecting text...")
            await textInjectionService.inject(text: result)

            // Re-check appState after await
            guard let appState = self.appState else { return }

            appState.recordingState = .idle
            appState.showFloatingPanel = false
            NSLog("[Sayit] Pipeline: Complete!")
        } catch {
            NSLog("[Sayit] Pipeline ERROR: %@", error.localizedDescription)
            guard let appState = self.appState else { return }
            appState.recordingState = .error(error.localizedDescription)

            // Auto-dismiss error after 3 seconds (cancellable)
            errorDismissTask?.cancel()
            errorDismissTask = Task { [weak self] in
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
