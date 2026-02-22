import Foundation

@MainActor
final class PipelineOrchestrator {
    private let speechService: AppleSpeechService
    private let textInjectionService: TextInjectionService
    private let openRouterService: OpenRouterSTTService?
    private weak var appState: AppState?
    private var errorDismissTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?

    init(
        speechService: AppleSpeechService,
        textInjectionService: TextInjectionService,
        openRouterService: OpenRouterSTTService?,
        appState: AppState
    ) {
        self.speechService = speechService
        self.textInjectionService = textInjectionService
        self.openRouterService = openRouterService
        self.appState = appState

        // Show interim results in the floating panel while recording
        speechService.onInterimResult = { [weak appState] text in
            Task { @MainActor in
                appState?.rawTranscript = text
            }
        }
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
            try speechService.startRecording()
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

        appState.recordingState = .processing

        // Wrap processing in a cancellable task
        processingTask?.cancel()
        processingTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                let appleResult = await self.speechService.stopAndTranscribe()

                // Check cancellation after recognition
                try Task.checkCancellation()

                guard let appState = self.appState else { return }

                var result = appleResult

                // If Apple Speech returned empty and OpenRouter is configured, try cloud STT
                if result.isEmpty, let openRouter = self.openRouterService, openRouter.isConfigured {
                    NSLog("[Sayit] Pipeline: Apple Speech empty, trying OpenRouter fallback...")
                    if let wavData = self.speechService.getRecordedWAVData() {
                        do {
                            result = try await openRouter.transcribe(wavData: wavData)
                            NSLog("[Sayit] Pipeline: OpenRouter result = %@", result)
                        } catch {
                            NSLog("[Sayit] Pipeline: OpenRouter fallback failed: %@", error.localizedDescription)
                        }
                    } else {
                        NSLog("[Sayit] Pipeline: No audio data available for OpenRouter fallback")
                    }
                }

                try Task.checkCancellation()

                guard !result.isEmpty else {
                    NSLog("[Sayit] Pipeline: No speech detected, skipping")
                    appState.recordingState = .idle
                    appState.showFloatingPanel = false
                    appState.floatingPanelController?.hidePanel()
                    return
                }

                NSLog("[Sayit] Pipeline: Result = %@", result)
                appState.refinedText = result

                // Inject text
                appState.recordingState = .injecting
                appState.floatingPanelController?.hidePanel()

                // Small delay to let panel hide and target app regain focus
                try await Task.sleep(for: .milliseconds(100))
                try Task.checkCancellation()

                NSLog("[Sayit] Pipeline: Injecting text...")
                await self.textInjectionService.inject(text: result)

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

                // Auto-dismiss error after 3 seconds
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
