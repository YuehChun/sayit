import SwiftUI
import Combine

enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case injecting
    case error(String)

    var isRecording: Bool { self == .recording }
    var isProcessing: Bool { self == .processing }

    var statusText: String {
        switch self {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .processing: return "Processing..."
        case .injecting: return "Injecting text..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var recordingState: RecordingState = .idle {
        didSet {
            if recordingState == .processing {
                processingStartTime = Date()
            } else if oldValue == .processing {
                processingStartTime = nil
            }
        }
    }
    @Published var rawTranscript: String = ""
    @Published var refinedText: String = ""
    @Published var showFloatingPanel: Bool = false
    @Published var showSettings: Bool = false
    @Published var processingStartTime: Date?

    private var servicesInitialized = false

    // Services (initialized after app launch)
    var audioCaptureManager: AudioCaptureManager?
    var pipelineOrchestrator: PipelineOrchestrator?
    var globalShortcutManager: GlobalShortcutManager?
    var floatingPanelController: FloatingPanelController?

    init() {
        // Delay slightly to ensure main run loop is ready
        DispatchQueue.main.async { [weak self] in
            self?.setupServices()
        }
    }

    func setupServices() {
        guard !servicesInitialized else { return }
        servicesInitialized = true

        NSLog("[Sayit] Setting up services...")

        let keychainManager = KeychainManager()
        let geminiService = GeminiSTTService(keychainManager: keychainManager)
        let openRouterService = OpenRouterSTTService(keychainManager: keychainManager)
        let textInjection = TextInjectionService()
        let audioCapture = AudioCaptureManager()

        let pipeline = PipelineOrchestrator(
            audioCaptureManager: audioCapture,
            geminiSTTService: geminiService,
            openRouterSTTService: openRouterService,
            keychainManager: keychainManager,
            textInjectionService: textInjection,
            appState: self
        )

        self.audioCaptureManager = audioCapture
        self.pipelineOrchestrator = pipeline

        let shortcutManager = GlobalShortcutManager { [weak self] isRecording in
            Task { @MainActor in
                guard let self = self else { return }
                if isRecording {
                    NSLog("[Sayit] Toggle: START recording")
                    self.pipelineOrchestrator?.startRecording()
                } else {
                    NSLog("[Sayit] Toggle: STOP recording")
                    await self.pipelineOrchestrator?.stopRecordingAndProcess()
                }
            }
        }
        self.globalShortcutManager = shortcutManager
        shortcutManager.start()

        let panelController = FloatingPanelController(appState: self)
        self.floatingPanelController = panelController

        NSLog("[Sayit] Services setup complete")
    }
}
