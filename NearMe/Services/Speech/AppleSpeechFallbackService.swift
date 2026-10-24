// Adapted from a prior prototype, used with permission.

import AVFoundation
import Speech

@MainActor
final class AppleSpeechFallbackService: NSObject, VoiceInputService {
    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private(set) var isListening = false

    private var silenceTimer: Timer?
    private let silenceInterval: TimeInterval = 1.4
    /// Backstop if the recognizer never calls back at all.
    private let hardTimeout: TimeInterval = 25

    /// The in-flight continuation's resolver, if a `startListening` call is
    /// currently pending — lets `stopListening()` resolve it directly rather
    /// than leaving it to leak.
    private var activeResume: ResumeOnce<String>?

    override init() {
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-AU"))
        super.init()
    }

    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw VoiceInputError.microphonePermissionDenied
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw VoiceInputError.speechPermissionDenied
        }
        guard let recognizer, recognizer.isAvailable else {
            throw VoiceInputError.recognizerUnavailable
        }

        isListening = true
        defer { isListening = false }

        // FIX: was a per-call setCategory/setActive here — see
        // NearMeAudioSession.swift. The session is configured once for the
        // whole conversation rather than being switched on every turn.
        try NearMeAudioSession.configureIfNeeded()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on-device recognition for privacy/latency when the device supports it.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        // Same defensive check as AudioFileRecorder — see that file's
        // header comment for why this can transiently be invalid right
        // after an audio-session category switch on a real device.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceInputError.microphoneUnavailable
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            self.request = nil
            throw VoiceInputError.audioEngineFailed(error)
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else { return }
            let resume = ResumeOnce(continuation)
            self.activeResume = resume
            var latestTranscript = ""

            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let error { VoiceDiagnostics.log(error) }
                guard self.activeResume === resume else { return }

                if let result {
                    latestTranscript = result.bestTranscription.formattedString
                    onPartialTranscript(latestTranscript)
                    self.resetSilenceTimer {
                        self.activeResume = nil
                        self.finish()
                        if latestTranscript.trimmingCharacters(in: .whitespaces).isEmpty {
                            resume.fulfill(throwing: VoiceInputError.noSpeechDetected)
                        } else {
                            resume.fulfill(returning: latestTranscript)
                        }
                    }
                }

                if let error {
                    self.activeResume = nil
                    self.finish()
                    if latestTranscript.trimmingCharacters(in: .whitespaces).isEmpty {
                        resume.fulfill(throwing: VoiceInputError.network(error))
                    } else {
                        // Some recognizer errors still arrive after a good final transcript
                        // (e.g. the task being cancelled once we stop) — prefer the transcript.
                        resume.fulfill(returning: latestTranscript)
                    }
                }
            }

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self?.hardTimeout ?? 25) * 1_000_000_000)
                guard let self, self.activeResume === resume else { return }
                self.activeResume = nil
                self.finish()
                resume.fulfill(throwing: VoiceInputError.noSpeechDetected)
            }
        }
    }

    func stopListening() {
        if let resume = activeResume {
            activeResume = nil
            resume.fulfill(throwing: VoiceInputError.noSpeechDetected)
        }
        finish()
    }

    private func resetSilenceTimer(onSilence: @escaping () -> Void) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceInterval, repeats: false) { _ in
            Task { @MainActor in onSilence() }
        }
    }

    private func finish() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        // No longer deactivates the shared session here — it stays active
        // for the whole conversation (see NearMeAudioSession.swift).
        isListening = false
    }
}
