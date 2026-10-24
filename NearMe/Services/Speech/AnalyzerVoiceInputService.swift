import AVFoundation
import Foundation
import Speech

/// Live audio stays in memory and is consumed only by the on-device analyzer.
@available(iOS 26.0, *)
@MainActor
final class AnalyzerVoiceInputService: VoiceInputService {
    private let transcriber: SpeechTranscriber
    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var pending: CheckedContinuation<String, Error>?
    private var generation = 0
    private var tapInstalled = false
    private(set) var isListening = false

    init(transcriber: SpeechTranscriber) { self.transcriber = transcriber }

    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        stopListening()
        let token = generation
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw VoiceInputError.microphonePermissionDenied
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw VoiceInputError.recognizerUnavailable
        }
        guard token == generation else { throw CancellationError() }
        try NearMeAudioSession.configureIfNeeded()
        let sourceFormat = engine.inputNode.outputFormat(forBus: 0)
        guard sourceFormat.sampleRate > 0, sourceFormat.channelCount > 0 else {
            throw VoiceInputError.microphoneUnavailable
        }
        let converter = try SpeechBufferConverter(from: sourceFormat, to: format)
        let stream = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        input = stream.continuation
        do {
            try await analyzer.start(inputSequence: stream.stream)
            guard token == generation else {
                await analyzer.cancelAndFinishNow()
                throw CancellationError()
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
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            resultsTask = Task { [weak self, transcriber] in
                var finalized = ""
                var latest = ""
                do {
                    for try await result in transcriber.results {
                        guard let self, token == self.generation else { return }
                        let segment = String(result.text.characters)
                        if result.isFinal { finalized += segment }
                        latest = result.isFinal ? finalized : finalized + segment
                        onPartialTranscript(latest)
                        self.silenceTask?.cancel()
                        let transcript = latest
                        self.silenceTask = Task { [weak self] in
                            do { try await Task.sleep(for: .seconds(1.4)) } catch { return }
                            guard let self, token == self.generation else { return }
                            self.complete(transcript)
                        }
                    }
                    guard let self, token == self.generation else { return }
                    self.complete(latest)
                } catch {
                    guard let self, token == self.generation else { return }
                    self.finish(.failure(VoiceInputError.recognizerUnavailable))
                }
            }
            timeoutTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(25)) } catch { return }
                guard let self, token == self.generation else { return }
                self.finish(.failure(VoiceInputError.noSpeechDetected))
            }
        }
    }

    func stopListening() { finish(.failure(CancellationError())) }

    private func complete(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        finish(text.isEmpty ? .failure(VoiceInputError.noSpeechDetected) : .success(text))
    }

    private func finish(_ result: Result<String, Error>) {
        generation += 1
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
        if let analyzer { Task { await analyzer.cancelAndFinishNow() } }
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
