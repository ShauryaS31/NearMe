// Adapted from a prior prototype, used with permission.

import AVFoundation

nonisolated final class AudioFileRecorder {
    struct Configuration {
        /// RMS level (0...1) below which audio is considered silence.
        var silenceThreshold: Float = 0.02
        /// How long silence must persist before we consider the user done talking.
        var silenceDuration: TimeInterval = 1.2
        /// Hard cap so a stuck session can't record forever.
        var maximumDuration: TimeInterval = 20
    }

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var config = Configuration()
    private var silenceStartedAt: Date?
    private var startedAt: Date?
    private var hasDetectedSpeech = false
    private var completion: ((Result<URL, VoiceInputError>) -> Void)?
    private var currentFileURL: URL?
    private let stateLock = NSLock()

    var onAmplitude: ((Float) -> Void)?

    func start(configuration: Configuration = Configuration(), completion: @escaping (Result<URL, VoiceInputError>) -> Void) throws {
        self.config = configuration
        self.completion = completion
        self.silenceStartedAt = nil
        self.hasDetectedSpeech = false
        self.startedAt = Date()

        // FIX: was a per-call setCategory/setActive here — see
        // NearMeAudioSession.swift. The session is configured once for the
        // whole conversation rather than being switched on every turn.
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw VoiceInputError.microphonePermissionDenied
        }
        try NearMeAudioSession.configureIfNeeded()

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceInputError.microphoneUnavailable
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nearme-\(UUID().uuidString).wav")
        currentFileURL = url
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer, url: url)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw VoiceInputError.audioEngineFailed(error)
        }
    }

    /// Ends recording. If a completion is still pending — this was called
    /// externally rather than reached naturally via silence/max-duration —
    /// it's resolved here too (see the header comment above).
    func stop() {
        teardownEngine()
        resolveIfNeeded(url: currentFileURL)
    }

    private func process(buffer: AVAudioPCMBuffer, url: URL) {
        do {
            try audioFile?.write(from: buffer)
        } catch {
            VoiceDiagnostics.log(error)
        }

        let level = rmsLevel(of: buffer)
        onAmplitude?(level)

        let now = Date()

        if let startedAt, now.timeIntervalSince(startedAt) > config.maximumDuration {
            finish(url: url)
            return
        }

        if level > config.silenceThreshold {
            hasDetectedSpeech = true
            silenceStartedAt = nil
        } else if hasDetectedSpeech {
            if silenceStartedAt == nil {
                silenceStartedAt = now
            } else if let silenceStartedAt, now.timeIntervalSince(silenceStartedAt) > config.silenceDuration {
                finish(url: url)
            }
        }
    }

    private func finish(url: URL) {
        teardownEngine()
        resolveIfNeeded(url: url)
    }

    private func teardownEngine() {
        guard engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        // No longer deactivates the shared session here — it stays active
        // for the whole conversation (see NearMeAudioSession.swift).
    }

    private func resolveIfNeeded(url: URL?) {
        stateLock.lock()
        guard let callback = completion else { stateLock.unlock(); return }
        completion = nil
        let didDetectSpeech = hasDetectedSpeech
        stateLock.unlock()

        let result: Result<URL, VoiceInputError>
        if didDetectSpeech, let url {
            result = .success(url)
        } else {
            result = .failure(.noSpeechDetected)
        }
        callback(result)
    }

    private func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        let samples = channelData[0]
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = samples[i]
            sum += sample * sample
        }
        return sqrt(sum / Float(frameLength))
    }
}
