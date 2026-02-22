import Speech
import AVFoundation

final class AppleSpeechService: @unchecked Sendable {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var engine: AVAudioEngine?
    private(set) var isRecording = false

    private var transcript = ""
    private let lock = NSLock()
    private var recordingGeneration: UInt64 = 0

    /// Called on every interim/partial result so the UI can show live text
    var onInterimResult: (@Sendable (String) -> Void)?

    // For awaiting the final result after stopAndTranscribe()
    private var pendingContinuation: CheckedContinuation<String, Never>?
    private var isFinalDelivered = false

    // Raw audio capture for cloud STT fallback
    private var rawSamples: [Float] = []
    private var captureSampleRate: Double = 0

    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
        NSLog("[Sayit] AppleSpeech: init, recognizer=%@, available=%@, onDevice=%@",
              speechRecognizer != nil ? "yes" : "no",
              speechRecognizer?.isAvailable == true ? "yes" : "no",
              speechRecognizer?.supportsOnDeviceRecognition == true ? "yes" : "no")
    }

    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                NSLog("[Sayit] AppleSpeech: authorization status = \(status.rawValue) (0=notDetermined, 1=denied, 2=restricted, 3=authorized)")
                continuation.resume(returning: status)
            }
        }
    }

    func startRecording() throws {
        guard !isRecording else { return }
        guard let speechRecognizer = speechRecognizer else {
            throw SayitError.audioError("Speech recognizer not available for zh-TW")
        }
        guard speechRecognizer.isAvailable else {
            throw SayitError.audioError("Speech recognition service is currently unavailable")
        }

        let engine = AVAudioEngine()
        self.engine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        // Do NOT force on-device — let the system decide (on-device model may not be downloaded)
        self.recognitionRequest = request

        recordingGeneration &+= 1
        let gen = recordingGeneration

        lock.lock()
        transcript = ""
        pendingContinuation = nil
        isFinalDelivered = false
        rawSamples = []
        captureSampleRate = 0
        lock.unlock()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self, self.recordingGeneration == gen else { return }

            if let error = error {
                NSLog("[Sayit] AppleSpeech: recognition error: \(error.localizedDescription) (domain=\((error as NSError).domain), code=\((error as NSError).code))")
            }

            if let result = result {
                let text = result.bestTranscription.formattedString
                NSLog("[Sayit] AppleSpeech: \(result.isFinal ? "FINAL" : "interim") = \(text)")

                self.lock.lock()
                self.transcript = text
                self.lock.unlock()

                self.onInterimResult?(text)

                if result.isFinal {
                    self.deliverFinalResult()
                }
            } else if error != nil {
                // Error with no result — deliver whatever we have
                self.deliverFinalResult()
            }
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw SayitError.audioError("No audio input available")
        }

        NSLog("[Sayit] AppleSpeech: input format = \(format)")

        captureSampleRate = format.sampleRate

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self, self.recordingGeneration == gen else { return }
            self.recognitionRequest?.append(buffer)

            // Capture raw audio for cloud STT fallback
            if let channelData = buffer.floatChannelData?[0] {
                let count = Int(buffer.frameLength)
                self.lock.lock()
                self.rawSamples.append(contentsOf: UnsafeBufferPointer(start: channelData, count: count))
                self.lock.unlock()
            }
        }

        try engine.start()
        isRecording = true
        NSLog("[Sayit] AppleSpeech: Started recording (gen=\(gen))")
    }

    func stopAndTranscribe() async -> String {
        guard isRecording else { return "" }

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        isRecording = false
        recognitionRequest?.endAudio()

        NSLog("[Sayit] AppleSpeech: Stopped, waiting for final result...")

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            self.lock.lock()
            if self.isFinalDelivered {
                let t = self.transcript
                self.lock.unlock()
                continuation.resume(returning: t)
                return
            }
            self.pendingContinuation = continuation
            self.lock.unlock()

            // Safety timeout — use whatever we have after 3s
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                NSLog("[Sayit] AppleSpeech: Timeout, delivering current transcript")
                self?.deliverFinalResult()
            }
        }

        cleanup()
        NSLog("[Sayit] AppleSpeech: Final transcript = \(result)")
        return result
    }

    private func deliverFinalResult() {
        lock.lock()
        guard !isFinalDelivered else {
            lock.unlock()
            return
        }
        isFinalDelivered = true
        let t = transcript
        let cont = pendingContinuation
        pendingContinuation = nil
        lock.unlock()

        cont?.resume(returning: t)
    }

    /// Returns the captured audio as WAV data (16-bit mono PCM) for cloud STT fallback.
    func getRecordedWAVData() -> Data? {
        lock.lock()
        let samples = rawSamples
        let rate = captureSampleRate
        lock.unlock()

        guard !samples.isEmpty, rate > 0 else { return nil }

        // Downsample to 16kHz for smaller payload (sufficient for speech)
        let targetRate = 16000.0
        let ratio = rate / targetRate
        let outputCount = Int(Double(samples.count) / ratio)
        guard outputCount > 0 else { return nil }

        // Convert to 16-bit PCM with downsampling
        var pcmData = Data(capacity: outputCount * 2)
        for i in 0..<outputCount {
            let srcIndex = Int(Double(i) * ratio)
            let clamped = max(-1.0, min(1.0, samples[min(srcIndex, samples.count - 1)]))
            var sample = Int16(clamped * Float(Int16.max))
            pcmData.append(Data(bytes: &sample, count: 2))
        }

        // Build WAV header
        let headerSize = 44
        let dataSize = pcmData.count
        let fileSize = headerSize + dataSize
        let sampleRateInt = UInt32(targetRate)
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRateInt * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)

        var header = Data(capacity: headerSize)
        header.append(contentsOf: "RIFF".utf8)
        header.append(littleEndian: UInt32(fileSize - 8))
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(littleEndian: UInt32(16)) // chunk size
        header.append(littleEndian: UInt16(1))  // PCM format
        header.append(littleEndian: channels)
        header.append(littleEndian: sampleRateInt)
        header.append(littleEndian: byteRate)
        header.append(littleEndian: blockAlign)
        header.append(littleEndian: bitsPerSample)
        header.append(contentsOf: "data".utf8)
        header.append(littleEndian: UInt32(dataSize))

        return header + pcmData
    }

    private func cleanup() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        engine = nil
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func append(littleEndian value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }

    mutating func append(littleEndian value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
