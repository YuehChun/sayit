@preconcurrency import AVFoundation
import Foundation

final class AudioCaptureManager: @unchecked Sendable {
    private var engine = AVAudioEngine()
    private var audioData = Data()
    private let sampleRate: Double = 8000
    private let lock = NSLock()
    private(set) var isRecording = false

    // Generation counter to discard callbacks from old recording sessions
    private var recordingGeneration: UInt64 = 0

    // Store converter/format as instance vars so tap closure doesn't hold dangling refs
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?

    func startRecording() throws {
        guard !isRecording else { return }

        // Create a fresh engine to pick up current audio device and avoid stale buffers
        engine = AVAudioEngine()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw SayitError.audioError("No audio input available")
        }

        guard let outFmt = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw SayitError.audioError("Failed to create output format")
        }

        guard let conv = AVAudioConverter(from: inputFormat, to: outFmt) else {
            throw SayitError.audioError("Failed to create audio converter")
        }

        self.outputFormat = outFmt
        self.converter = conv

        // Increment generation and clear buffer
        recordingGeneration &+= 1
        let currentGeneration = recordingGeneration

        lock.lock()
        audioData = Data()
        lock.unlock()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Discard if this callback is from a stale session
            guard self.recordingGeneration == currentGeneration else { return }
            self.convertAndAppend(buffer: buffer)
        }

        do {
            try engine.start()
            isRecording = true
            NSLog("[Sayit] AudioCapture: Started recording (gen=%llu, inputRate=%.0f)", currentGeneration, inputFormat.sampleRate)
        } catch {
            // Clean up tap if engine failed to start
            inputNode.removeTap(onBus: 0)
            self.converter = nil
            self.outputFormat = nil
            throw SayitError.audioError("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    func stopRecording() -> Data {
        guard isRecording else { return Data() }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
        isRecording = false
        self.converter = nil
        self.outputFormat = nil

        lock.lock()
        let pcmData = audioData
        audioData = Data()
        lock.unlock()

        NSLog("[Sayit] AudioCapture: Stopped recording, PCM size = %d bytes", pcmData.count)
        return createWAV(from: pcmData)
    }

    private func convertAndAppend(buffer: AVAudioPCMBuffer) {
        guard let converter = self.converter,
              let outputFormat = self.outputFormat else { return }

        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate
        )
        guard frameCount > 0 else { return }

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
            return
        }

        var error: NSError?
        nonisolated(unsafe) var hasData = false
        nonisolated(unsafe) let inputBuffer = buffer
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasData = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if error != nil { return }

        guard let channelData = outputBuffer.int16ChannelData else { return }
        let data = Data(bytes: channelData[0], count: Int(outputBuffer.frameLength) * 2)

        lock.lock()
        audioData.append(data)
        lock.unlock()
    }

    private func createWAV(from pcmData: Data) -> Data {
        var wav = Data()
        let dataSize = UInt32(pcmData.count)
        let fileSize = dataSize + 36

        // RIFF header
        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        wav.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM format
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(8000).littleEndian) { Array($0) }) // sample rate
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16000).littleEndian) { Array($0) }) // byte rate
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // block align
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample

        // data chunk
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        wav.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        wav.append(pcmData)

        return wav
    }
}
