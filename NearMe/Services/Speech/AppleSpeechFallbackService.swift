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
    private var latestTranscript = ""

    init(locale: Locale = Locale(identifier: "en-AU")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
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
        guard recognizer.supportsOnDeviceRecognition == true else {
            throw VoiceInputError.unsupportedOnDeviceLocale
        }

        isListening = true
        defer { isListening = false }

        // FIX: was a per-call setCategory/setActive here — see
        // NearMeAudioSession.swift. The session is configured once for the
        // whole conversation rather than being switched on every turn.
        try NearMeAudioSession.configureIfNeeded()

        let request = Self.makeRecognitionRequest()
        self.request = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        // Hardware can briefly report an invalid format after activation.
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
            self.latestTranscript = ""

            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let error { VoiceDiagnostics.log(error) }
                let transcript = result?.bestTranscription.formattedString
                let failed = error != nil
                Task { @MainActor in
                    guard let self else { return }
                    guard self.activeResume === resume else { return }

                    if let transcript {
                        self.latestTranscript = transcript
                        onPartialTranscript(transcript)
                        self.resetSilenceTimer {
                            guard self.activeResume === resume else { return }
                            self.activeResume = nil
                            self.finish()
                            if self.latestTranscript.trimmingCharacters(in: .whitespaces).isEmpty {
                                resume.fulfill(throwing: VoiceInputError.noSpeechDetected)
                            } else {
                                resume.fulfill(returning: self.latestTranscript)
                            }
                        }
                    }

                    if failed {
                        self.activeResume = nil
                        self.finish()
                        if self.latestTranscript.trimmingCharacters(in: .whitespaces).isEmpty {
                            resume.fulfill(throwing: VoiceInputError.recognizerUnavailable)
                        } else {
                            // Prefer a usable transcript if cancellation follows it.
                            resume.fulfill(returning: self.latestTranscript)
                        }
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

    static func makeRecognitionRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        return request
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
