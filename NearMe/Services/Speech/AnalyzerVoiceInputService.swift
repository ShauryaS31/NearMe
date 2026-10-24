import AVFoundation
import Foundation
import OSLog
import Speech

@available(iOS 26.0, *)
@MainActor
protocol SpeechAnalysisControlling: AnyObject {
    func setContext(_ context: AnalysisContext) async throws
    func start(inputSequence: AsyncStream<AnalyzerInput>) async throws
    func finalizeAndFinishThroughEndOfInput() async throws
    func cancelAndFinishNow() async
}

@available(iOS 26.0, *)
@MainActor
private final class SystemSpeechAnalysis: SpeechAnalysisControlling {
    private let analyzer: SpeechAnalyzer

    init(transcriber: SpeechTranscriber) {
        analyzer = SpeechAnalyzer(modules: [transcriber])
    }

    func setContext(_ context: AnalysisContext) async throws { try await analyzer.setContext(context) }
    func start(inputSequence: AsyncStream<AnalyzerInput>) async throws {
        try await analyzer.start(inputSequence: inputSequence)
    }
    func finalizeAndFinishThroughEndOfInput() async throws {
        try await analyzer.finalizeAndFinishThroughEndOfInput()
    }
    func cancelAndFinishNow() async { await analyzer.cancelAndFinishNow() }
}

/// One module and analyzer per listen. The vocabulary is installed before input starts.
@available(iOS 26.0, *)
@MainActor
final class SpeechAnalysisSession {
    let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalysisControlling

    init(locale: Locale, makeAnalyzer: (SpeechTranscriber) -> SpeechAnalysisControlling) {
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                           reportingOptions: [.volatileResults], attributeOptions: [.transcriptionConfidence])
        self.transcriber = transcriber
        self.analyzer = makeAnalyzer(transcriber)
    }

    func start(inputSequence: AsyncStream<AnalyzerInput>, isCurrent: () -> Bool = { true }) async throws {
        try await analyzer.setContext(PracticeVocabulary.analysisContext())
        try Task.checkCancellation()
        guard isCurrent() else { throw CancellationError() }
        try await analyzer.start(inputSequence: inputSequence)
    }
    func finalizeAndFinishThroughEndOfInput() async throws {
        try await analyzer.finalizeAndFinishThroughEndOfInput()
    }
    func cancelAndFinishNow() async { await analyzer.cancelAndFinishNow() }
}

/// Live audio stays in memory and is consumed only by the on-device analyzer.
@available(iOS 26.0, *)
@MainActor
final class AnalyzerVoiceInputService: VoiceInputService {
    private let locale: Locale
    private let makeAnalyzer: (SpeechTranscriber) -> SpeechAnalysisControlling
    private lazy var engine = AVAudioEngine()
    private var cleanupTask: Task<Void, Never>?
    private var analyzer: SpeechAnalysisSession?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var finalizationTask: Task<Void, Never>?
    private var silenceRule = SpeechSilenceRule()
    private var latestTranscript = ""
    private var ending = false
    private var finishRequested = false
    private var voiceProcessing = false
    private var endReason: SpeechEndReason?
    private var captureDuration: TimeInterval = 0
    var acceptsTranscript: () -> Bool = { true }
    private(set) var lastTurn = SpeechTurn()
    var onSpeechEnd: ((String) -> Void)?
    private var silenceTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var pending: CheckedContinuation<String, Error>?
    private var generation = 0
    private var tapInstalled = false
    private(set) var isListening = false

    init(locale: Locale, makeAnalyzer: ((SpeechTranscriber) -> SpeechAnalysisControlling)? = nil) {
        self.locale = locale
        self.makeAnalyzer = makeAnalyzer ?? { SystemSpeechAnalysis(transcriber: $0) }
    }

    func makeSession() -> SpeechAnalysisSession {
        SpeechAnalysisSession(locale: locale, makeAnalyzer: makeAnalyzer)
    }

    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        stopListening()
        finishRequested = false
        let token = generation
        await cleanupTask?.value
        guard token == generation else { throw CancellationError() }
        silenceRule = SpeechSilenceRule()
        lastTurn = SpeechTurn()
        latestTranscript = ""
        ending = false
        endReason = nil
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw VoiceInputError.microphonePermissionDenied
        }
        let analyzer = makeSession()
        let transcriber = analyzer.transcriber
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw VoiceInputError.recognizerUnavailable
        }
        guard token == generation else { throw CancellationError() }
        try NearMeAudioSession.configureIfNeeded()
        voiceProcessing = false
        do {
            try engine.inputNode.setVoiceProcessingEnabled(true)
            voiceProcessing = engine.inputNode.isVoiceProcessingEnabled
        } catch { VoiceDiagnostics.log(error) }
        VoiceDiagnostics.logger.info("Input voice processing=\(self.voiceProcessing ? "on" : "off", privacy: .public)")
        let sourceFormat = engine.inputNode.outputFormat(forBus: 0)
        guard sourceFormat.sampleRate > 0, sourceFormat.channelCount > 0 else {
            throw VoiceInputError.microphoneUnavailable
        }
        let converter = try SpeechBufferConverter(from: sourceFormat, to: format)
        let stream = AsyncStream<AnalyzerInput>.makeStream()
        self.analyzer = analyzer
        input = stream.continuation
        do {
            try await analyzer.start(inputSequence: stream.stream, isCurrent: { token == self.generation })
            guard token == generation else {
                await analyzer.cancelAndFinishNow()
                throw CancellationError()
            }
            if finishRequested {
                // A tap during analyzer preparation must not open the microphone afterwards.
                silenceRule.logEnd(reason: .tap, transcript: "", voiceProcessing: voiceProcessing, duration: 0)
                throw VoiceInputError.noSpeechDetected
            }
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: sourceFormat) { [weak self] buffer, _ in
                do {
                    let converted = try converter.convert(buffer)
                    stream.continuation.yield(AnalyzerInput(buffer: converted))
                } catch {
                    Task { @MainActor in
                        guard let self, token == self.generation else { return }
                        self.finish(.failure(VoiceInputError.microphoneUnavailable))
                    }
                }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
        } catch {
            if token == generation { finish(.failure(error)) }
            throw error
        }
        isListening = true
        silenceRule = SpeechSilenceRule()
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            resultsTask = Task { [weak self, transcriber] in
                var finalized = ""
                var latest = ""
                var finalizedConfidence: [Double] = []
                do {
                    for try await result in transcriber.results {
                        guard let self, token == self.generation else { return }
                        guard self.acceptsTranscript() else { continue }
                        let segment = String(result.text.characters)
                        let confidence = result.text.runs.compactMap { run in
                            run[AttributeScopes.SpeechAttributes.ConfidenceAttribute.self].map { Double($0) }
                        }
                        if result.isFinal {
                            finalized += segment
                            finalizedConfidence += confidence
                        }
                        latest = result.isFinal ? finalized : finalized + segment
                        let allConfidence = result.isFinal ? finalizedConfidence : finalizedConfidence + confidence
                        self.lastTurn.confidence = allConfidence.isEmpty ? nil : allConfidence.reduce(0, +) / Double(allConfidence.count)
                        self.latestTranscript = latest
                        self.silenceRule.observe(transcript: latest)
                        onPartialTranscript(latest)
                    }
                    guard let self, token == self.generation else { return }
                    self.complete(latest)
                } catch {
                    guard let self, token == self.generation else { return }
                    if self.ending { self.complete(self.latestTranscript) }
                    else { self.finish(.failure(VoiceInputError.recognizerUnavailable)) }
                }
            }
            silenceTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
                    guard let self, token == self.generation else { return }
                    if let reason = self.silenceRule.endReason {
                        self.endSpeech(token: token, reason: reason)
                        return
                    }
                }
            }
        }
    }

    func finishListening() {
        finishRequested = true
        if pending != nil { endSpeech(token: generation, reason: .tap) }
    }

    func stopListening() { finish(.failure(CancellationError())) }

    private func endSpeech(token: Int, reason: SpeechEndReason) {
        guard !ending else { return }
        ending = true
        endReason = reason
        captureDuration = silenceRule.duration
        lastTurn.endedAt = ProcessInfo.processInfo.systemUptime
        silenceTask?.cancel()
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        isListening = false
        input?.finish()
        input = nil
        onSpeechEnd?(latestTranscript)
        timeoutTask?.cancel()
        finalizationTask = Task { [weak self] in
            guard let self, let analyzer = self.analyzer else { return }
            do { try await analyzer.finalizeAndFinishThroughEndOfInput() }
            catch {
                guard token == self.generation else { return }
                self.complete(self.latestTranscript)
            }
            // The results stream completes with the final transcript.
        }
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(SpeechSilenceRule.finalResultWait)) } catch { return }
            guard let self, token == self.generation else { return }
            self.complete(self.latestTranscript)
        }
    }

    private func complete(_ text: String) {
        if endReason == nil {
            endReason = .wordsSettled
            captureDuration = silenceRule.duration
            lastTurn.endedAt = ProcessInfo.processInfo.systemUptime
        }
        silenceRule.logEnd(reason: endReason ?? .wordsSettled, transcript: text,
                           voiceProcessing: voiceProcessing, duration: captureDuration)
        finish(SpeechTurn.transcriptResult(text))
    }

    private func finish(_ result: Result<String, Error>) {
        generation += 1
        finalizationTask?.cancel()
        finalizationTask = nil
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        input?.finish()
        input = nil
        resultsTask?.cancel()
        resultsTask = nil
        silenceTask?.cancel()
        silenceTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        if let analyzer { cleanupTask = Task { await analyzer.cancelAndFinishNow() } }
        analyzer = nil
        isListening = false
        let continuation = pending
        pending = nil
        continuation?.resume(with: result)
    }
}

/// Used only on the audio tap's serial callback, never across concurrent taps.
nonisolated private final class SpeechBufferConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let target: AVAudioFormat

    init(from source: AVAudioFormat, to target: AVAudioFormat) throws {
        guard let converter = AVAudioConverter(from: source, to: target) else {
            throw VoiceInputError.microphoneUnavailable
        }
        converter.primeMethod = .none
        self.converter = converter
        self.target = target
    }

    func convert(_ source: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let capacity = AVAudioFrameCount(ceil(Double(source.frameLength) * target.sampleRate / source.format.sampleRate)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            throw VoiceInputError.microphoneUnavailable
        }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied { inputStatus.pointee = .noDataNow; return nil }
            supplied = true
            inputStatus.pointee = .haveData
            return source
        }
        if let error { throw error }
        guard status != .error else { throw VoiceInputError.microphoneUnavailable }
        return output
    }
}
