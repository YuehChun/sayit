# Sayit

AI-powered speech-to-text input for macOS. Speak naturally and get polished, publication-ready text injected directly into any application.

## How It Works

```
Microphone Audio → [Gemini API: Speech-to-Text] → Raw Text → [Text Refinement] → Polished Output → Target App
```

Sayit captures your voice via a global keyboard shortcut, transcribes it using Google Gemini's multimodal audio API, refines the raw transcript (removing filler words, fixing grammar, adding punctuation), and injects the final text into whatever app you're using.

## Features

- **Global Push-to-Talk** — Hold `Right Option (⌥)` anywhere in macOS to start recording, release to process
- **AI-Powered Transcription** — Google Gemini API for high-accuracy speech recognition
- **Smart Text Refinement** — Automatically cleans up filler words, repetitions, and grammar issues
- **Multi-Language Support** — Traditional Chinese, English, and mixed-language (code-switching) support
- **Universal Text Injection** — Injects text into any macOS app via Accessibility API
- **Floating Panel** — Minimal floating window shows recording status and live progress
- **Menu Bar App** — Lives in your menu bar, zero interference with your workflow

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac
- [Google Gemini API Key](https://aistudio.google.com/apikey)

## Getting Started

### Build from Source

```bash
# Clone the repository
git clone https://github.com/YuehChun/sayit.git
cd sayit

# Build
swift build

# Build release & create .app bundle
./scripts/bundle.sh
```

### Setup

1. Launch Sayit — it appears in your menu bar
2. Open **Settings** and enter your **Gemini API Key**
3. Grant **Microphone** and **Accessibility** permissions when prompted
4. Hold `Right Option (⌥)` to record, release to transcribe and inject

## Architecture

```
Sources/Sayit/
├── SayitApp.swift                    # App entry point
├── AppState.swift                    # Global state management
├── Services/
│   ├── AI/
│   │   ├── GeminiSTTService.swift        # Gemini speech-to-text
│   │   └── PipelineOrchestrator.swift    # Recording → STT → Refinement pipeline
│   ├── Audio/
│   │   └── AudioCaptureManager.swift     # Microphone capture (AVAudioEngine)
│   ├── Data/
│   │   └── KeychainManager.swift         # Secure API key storage (macOS Keychain)
│   └── System/
│       ├── GlobalShortcutManager.swift   # Global keyboard shortcut listener
│       └── TextInjectionService.swift    # Text injection via Accessibility API
└── UI/
    ├── FloatingPanelController.swift     # NSPanel window controller
    ├── FloatingPanelView.swift           # Recording status & progress UI
    ├── MenuBarView.swift                 # Menu bar interface
    └── SettingsView.swift                # API key & preferences
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Platform | macOS (Swift 6 / SwiftUI) |
| Speech-to-Text | Google Gemini API (`gemini-2.5-flash-lite`) |
| Audio Capture | AVFoundation / AVAudioEngine |
| System Integration | macOS Accessibility API, CGEvent |
| Key Storage | macOS Keychain |
| Package Manager | Swift Package Manager |

## Privacy

- Audio is never stored on disk — processed in memory only
- API keys are stored in macOS Keychain (encrypted)
- No telemetry or data collection
- All API calls use HTTPS

## License

MIT
