// Adapted from a prior prototype, used with permission.

import AVFoundation
import OSLog
import Speech

@MainActor
final class AppleSpeechFallbackService: NSObject, VoiceInputService {
    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private(set) var isListening = false

    private var silenceTask: Task<Void, Never>?
    private var finalizationTask: Task<Void, Never>?
    private var silenceRule = SpeechSilenceRule()
    private var ending = false
    private var receivedFinal = false
    private var voiceProcessing = false
    private var endReason: SpeechEndReason?
    private var captureDuration: TimeInterval = 0
    var acceptsTranscript: () -> Bool = { true }
    private var generation = 0
    private(set) var lastTurn = SpeechTurn()
    var onSpeechEnd: ((String) -> Void)?

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

        stopListening()
        let token = generation
        lastTurn = SpeechTurn()
        silenceRule = SpeechSilenceRule()
        ending = false
        receivedFinal = false
        endReason = nil
        isListening = true
        defer { if generation == token { isListening = false } }

        // FIX: was a per-call setCategory/setActive here — see
        // NearMeAudioSession.swift. The session is configured once for the
        // whole conversation rather than being switched on every turn.
        try NearMeAudioSession.configureIfNeeded()
        voiceProcessing = false
        do {
            try engine.inputNode.setVoiceProcessingEnabled(true)
            voiceProcessing = engine.inputNode.isVoiceProcessingEnabled
        } catch { VoiceDiagnostics.log(error) }
        VoiceDiagnostics.logger.info("Input voice processing=\(self.voiceProcessing ? "on" : "off", privacy: .public)")

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

        silenceRule = SpeechSilenceRule()
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else { return }
            let resume = ResumeOnce(continuation)
            self.activeResume = resume
            self.latestTranscript = ""

            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let error { VoiceDiagnostics.log(error) }
                let transcript = result?.bestTranscription.formattedString
                let failed = error != nil
                let final = result?.isFinal == true
                let confidences = result?.bestTranscription.segments.map { Double($0.confidence) } ?? []
                let confidence = confidences.isEmpty ? nil : confidences.reduce(0, +) / Double(confidences.count)
                Task { @MainActor in
                    guard let self else { return }
                    guard self.activeResume === resume else { return }

                    if let transcript, self.acceptsTranscript() {
                        self.latestTranscript = transcript
                        self.silenceRule.observe(transcript: transcript)
                        onPartialTranscript(transcript)
                        self.lastTurn.confidence = confidence
                        self.receivedFinal = final
                        if final, self.ending { self.complete(resume) }

                    }

                    if failed, self.activeResume === resume {
                        if self.ending { self.complete(resume); return }
                        self.silenceRule.logEnd(reason: .wordsSettled, transcript: self.latestTranscript,
                                               voiceProcessing: self.voiceProcessing, duration: self.silenceRule.duration)
                        self.activeResume = nil
                        self.finish()
                        let failure: VoiceInputError = self.recognizer?.isAvailable == false
                            ? .recognizerUnavailable : .noSpeechDetected
                        resume.fulfill(throwing: failure)
                    }
                }
            }

            self.silenceTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
                    guard let self, self.activeResume === resume else { return }
                    if let reason = self.silenceRule.endReason {
                        self.endSpeech(resume, reason: reason)
                        return
                    }
                }
            }
        }
    }

    func finishListening() {
        if let resume = activeResume { endSpeech(resume, reason: .tap) }
    }

    func stopListening() {
        if let resume = activeResume {
            activeResume = nil
            resume.fulfill(throwing: CancellationError())
        }
        finish()
    }

    private func endSpeech(_ resume: ResumeOnce<String>, reason: SpeechEndReason) {
        guard !ending else { return }
        ending = true
        endReason = reason
        captureDuration = silenceRule.duration
        lastTurn.endedAt = ProcessInfo.processInfo.systemUptime
        silenceTask?.cancel()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        isListening = false
        onSpeechEnd?(latestTranscript)
        request?.endAudio()
        if receivedFinal { complete(resume); return }
        finalizationTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(SpeechSilenceRule.finalResultWait)) } catch { return }
            guard let self, self.activeResume === resume else { return }
            self.complete(resume)
        }
    }

    private func complete(_ resume: ResumeOnce<String>) {
        silenceRule.logEnd(reason: endReason ?? .wordsSettled, transcript: latestTranscript,
                           voiceProcessing: voiceProcessing, duration: captureDuration)
        activeResume = nil
        let result = SpeechTurn.transcriptResult(latestTranscript)
        finish()
        switch result {
        case .success(let transcript): resume.fulfill(returning: transcript)
        case .failure(let error): resume.fulfill(throwing: error)
        }
    }

    static func makeRecognitionRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.contextualStrings = PracticeVocabulary.phrases
        return request
    }

    private func finish() {
        generation += 1
        silenceTask?.cancel()
        silenceTask = nil
        finalizationTask?.cancel()
        finalizationTask = nil
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
