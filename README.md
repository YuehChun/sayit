# Sayit

AI-powered speech-to-text input for macOS. Speak naturally and get polished, publication-ready text injected directly into any application.

## How It Works

```
Microphone → [Apple Speech: On-Device STT] → Raw Text
                     ↓ (empty?)
             [Gemini API: Cloud STT] → Refined Text
                     ↓ (quota exceeded?)
             [OpenRouter API: Fallback STT] → Refined Text
                     ↓
              Text Injection → Target App
```

Sayit captures your voice via a global keyboard shortcut, transcribes it using a 3-tier fallback chain (Apple Speech → Gemini → OpenRouter), and injects the final text into whatever app you're using.

## Features

- **Global Push-to-Talk** — Hold `Fn` key anywhere in macOS to start recording, release to process. `Option+R` as alternative toggle.
- **3-Tier STT Fallback** — Apple Speech (on-device) → Gemini API → OpenRouter, automatic failover
- **Short Recording Filter** — Recordings under 3 seconds are automatically discarded (likely noise/accidental triggers)
- **Smart Text Refinement** — Recordings over 10 seconds are automatically refined via OpenRouter to remove filler words (嗯、啊、呃、那個) and redundancies
- **Multi-Language Support** — Traditional Chinese, English, and mixed-language (code-switching) support
- **Universal Text Injection** — Injects text into any macOS app via Accessibility API
- **Floating Panel** — Minimal floating window at screen bottom shows recording status and live progress
- **Menu Bar App** — Lives in your menu bar, zero interference with your workflow

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac
- [Google Gemini API Key](https://aistudio.google.com/apikey) (optional, for cloud STT)
- [OpenRouter API Key](https://openrouter.ai/keys) (optional, fallback when Gemini quota exceeded)

## Getting Started

### Build from Source

```bash
# Clone the repository
git clone https://github.com/YuehChun/sayit.git
cd sayit

# Build
swift build

# Install to /Applications
cp .build/debug/Sayit /Applications/Sayit.app/Contents/MacOS/Sayit
codesign --force --sign - --identifier com.sayit.app /Applications/Sayit.app
```

### Setup

1. Launch Sayit — it appears in your menu bar
2. Grant **Microphone**, **Speech Recognition**, and **Accessibility** permissions when prompted
3. (Optional) Open **Settings** and enter your **Gemini API Key** and/or **OpenRouter API Key** for cloud STT
4. Hold `Fn` to record, release to transcribe and inject. Or use `Option+R` to toggle.

## STT Fallback Chain

| Priority | Provider | Model | Cost | Notes |
|----------|----------|-------|------|-------|
| 1 | Apple Speech | On-device | Free | Primary, no API key needed |
| 2 | Gemini API | gemini-2.5-flash-lite | ~$0.30/M tokens | Cloud STT when Apple Speech returns empty |
| 3 | OpenRouter | google/gemini-2.5-flash | ~$1/M audio tokens | Fallback when Gemini quota exceeded (429/503) |

## Architecture

```
Sources/Sayit/
├── SayitApp.swift                    # App entry point
├── AppState.swift                    # Global state management
├── SayitError.swift                  # Error types
├── Services/
│   ├── AI/
│   │   ├── GeminiSTTService.swift        # Gemini cloud STT
│   │   ├── OpenRouterSTTService.swift    # OpenRouter cloud STT fallback
│   │   └── PipelineOrchestrator.swift    # Recording → STT → Injection pipeline
│   ├── Audio/
│   │   └── AppleSpeechService.swift      # macOS native STT (SFSpeechRecognizer)
│   ├── Data/
│   │   └── KeychainManager.swift         # Secure API key storage (macOS Keychain)
│   └── System/
│       ├── GlobalShortcutManager.swift   # Fn key & Option+R shortcuts
│       └── TextInjectionService.swift    # Text injection via Accessibility API
└── UI/
    ├── FloatingPanelController.swift     # NSPanel window controller
    ├── FloatingPanelView.swift           # Recording status & progress UI
    ├── MenuBarView.swift                 # Menu bar interface
    └── SettingsView.swift                # API key & permissions settings
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Platform | macOS (Swift 6 / SwiftUI) |
| Primary STT | Apple Speech Framework (SFSpeechRecognizer) |
| Cloud STT | Google Gemini API, OpenRouter API |
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
