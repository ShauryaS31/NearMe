import Foundation
import OSLog

@MainActor
protocol CommandSpeechInput: AnyObject {
    var onResult: ((String, Bool) -> Void)? { get set }
    var onFailure: (() -> Void)? { get set }
    var onCaptureLost: (() -> Void)? { get set }
    var onAudioHint: (() -> Void)? { get set }
    var otherAudio: Bool { get }
    var allowsOtherAudio: Bool { get set }
    func startCapture() throws
    func startRecognition() throws
    func pauseRecognition()
    func stopCapture()
}

/// The capture lease starts in the foreground and survives recognition pauses.
/// All timing is injected so tests need neither a microphone nor wall-clock waits.
@MainActor
final class HandsFreeVoiceCommands {
    private let input: any CommandSpeechInput
    private let now: () -> TimeInterval
    private(set) var status: VoiceCommandStatus = .off {
        didSet { if status != oldValue { onStatus?(status) } }
    }
    var onStatus: ((VoiceCommandStatus) -> Void)?
    var onCommand: ((VoiceCommand) async -> Void)?
    var pendingQuestion: (() -> ScreenCoachLoop.Question?)?
    var onAnswer: ((String, ScreenCoachLoop.Question) async -> Void)?
    var isHandlingCommand: Bool { busy }
    var hasCapture: Bool { capturing && !stopped }
    private var audioWindowUntil: TimeInterval?
    var isAudioWindowOpen: Bool { audioWindowUntil.map { now() < $0 } ?? false }
    private var guideID: UUID?
    private var foreground = false
    private var sharing = false
    private var lostAt: TimeInterval?
    private var stopped = false
    private var capturing = false
    private var recognizing = false
    private var speaking = false
    private var busy = false
    private var settleUntil: TimeInterval = 0
    private var retryAt: TimeInterval?
    private var failures = 0
    private var partial = ""
    private var partialText = ""
    private var recognitionQuestion: ScreenCoachLoop.Question?
    private var partialSince: TimeInterval = 0
    private var recognitionSince: TimeInterval = 0
    private var generation = 0
    private var commandTask: Task<Void, Never>?

    init(input: any CommandSpeechInput, now: @escaping () -> TimeInterval) {
        self.input = input
        self.now = now
        input.onResult = { [weak self] text, final in self?.receive(text, final: final) }
        input.onFailure = { [weak self] in self?.failed() }
        input.onCaptureLost = { [weak self] in
            guard let self, self.hasCapture else { return }
            self.requireResume()
        }
        input.onAudioHint = { [weak self] in self?.tick() }
    }

    func update(guideID: UUID?, sharing: Bool, foreground: Bool) {
        if self.guideID != guideID {
            stop()
            self.guideID = guideID
            stopped = false
            failures = 0
        }
        self.foreground = foreground
        self.sharing = sharing
        guard guideID != nil else { return }
        if sharing { lostAt = nil }
        else if lostAt == nil { lostAt = now() }
        if capturing, let lostAt, now() - lostAt > 10 { stop(); return }
        tick()
    }

    func setSpeaking(_ value: Bool) {
        guard speaking != value else { return }
        speaking = value
        if value { closeAudioWindow(); pause() }
        else { settleUntil = now() + 0.15 }
    }

    func resume() {
        guard guideID != nil, foreground, sharing else { return }
        stopped = false
        failures = 0
        retryAt = nil
        tick()
    }

    func requireResume() {
        stop()
        status = .paused
    }

    /// An explicit warm Live Activity action can allow one prefixed response
    /// during other-app playback. Never acquire a microphone from this action.
    func requestAudioWindow() {
        guard hasCapture, sharing, !speaking else { return }
        pause()
        audioWindowUntil = now() + 8
        input.allowsOtherAudio = true
        tick()
    }

    private func closeAudioWindow() {
        guard audioWindowUntil != nil else { return }
        audioWindowUntil = nil
        input.allowsOtherAudio = false
        pause()
        if hasCapture { status = input.otherAudio ? .waitingForAudio : .listening }
    }

    func stop(cancelAction: Bool = true) {
        closeAudioWindow()
        generation += 1
        if cancelAction { commandTask?.cancel() }
        commandTask = nil
        busy = false
        pause()
        input.stopCapture()
        capturing = false
        retryAt = nil
        stopped = true
        status = .off
    }

    func tick() {
        guard guideID != nil, !stopped else { return }
        if audioWindowUntil != nil, !isAudioWindowOpen || !sharing || speaking { closeAudioWindow() }
        let blocksOtherAudio = input.otherAudio && !isAudioWindowOpen
        if speaking || blocksOtherAudio || busy {
            pause()
        }
        if let retryAt, now() < retryAt { return }
        if !capturing {
            // Never acquire/reacquire the microphone after the app handoff.
            if !foreground, retryAt != nil { requireResume(); return }
            guard foreground, sharing else { return }
            do {
                try input.startCapture()
                capturing = true
                status = .listening
            } catch { failed(); return }
        }
        status = isAudioWindowOpen ? .commandWindow : (input.otherAudio ? .waitingForAudio : .listening)
        guard !speaking, !blocksOtherAudio, !busy, now() >= settleUntil else { return }
        if recognizing, recognitionQuestion != pendingQuestion?() { pause() }
        if !recognizing {
            do {
                recognitionQuestion = pendingQuestion?()
                try input.startRecognition()
                recognizing = true
                recognitionSince = now()
                retryAt = nil
            } catch { failed(); return }
        }
        if !partial.isEmpty, now() - partialSince >= 0.6, let command = matchedCommand(partial) {
            accept(command)
        } else if !partial.isEmpty, now() - partialSince >= 1.2,
                  let question = recognitionQuestion, question == pendingQuestion?(),
                  let answer = ScreenVoiceAnswer.bounded(partialText, question: question) {
            acceptAnswer(answer, question: question)
        } else if now() - recognitionSince >= 55 {
            failed()
        }
    }

    private func receive(_ text: String, final: Bool) {
        if audioWindowUntil != nil, !isAudioWindowOpen { closeAudioWindow(); tick(); return }
        guard recognizing, !speaking, !busy, (!input.otherAudio || isAudioWindowOpen), now() >= settleUntil else { return }
        guard recognitionQuestion == pendingQuestion?() else { pause(); tick(); return }
        let candidate: String
        if isAudioWindowOpen {
            guard let payload = VoiceCommand.prefixedPayload(text) else {
                partial = ""
                partialText = ""
                if final { pause(); tick() }
                return
            }
            candidate = payload
        } else { candidate = text }
        let normalized = VoiceCommand.normalized(candidate)
        if partial != normalized { partial = normalized; partialSince = now() }
        partialText = candidate
        if final {
            if let command = matchedCommand(candidate) { accept(command) }
            else if let question = recognitionQuestion,
                    let answer = ScreenVoiceAnswer.bounded(candidate, question: question) {
                acceptAnswer(answer, question: question)
            }
            else { pause(); tick() } // Other speech is discarded silently.
        }
    }

    private func accept(_ command: VoiceCommand) {
        closeAudioWindow()
        pause()
        failures = 0
        busy = true
        let token = generation
        VoiceDiagnostics.logger.info("Command=\(command.rawValue, privacy: .public)")
        commandTask = Task { [weak self] in
            guard let self, token == self.generation, !Task.isCancelled else { return }
            await self.onCommand?(command)
            guard token == self.generation else { return }
            self.busy = false
            self.commandTask = nil
            self.tick()
        }
    }

    private func pause() {
        recognizing = false
        partial = ""
        partialText = ""
        input.pauseRecognition()
    }

    private func acceptAnswer(_ answer: String, question: ScreenCoachLoop.Question) {
        closeAudioWindow()
        pause()
        failures = 0
        busy = true
        let token = generation
        VoiceDiagnostics.logger.info("Command=screen answer")
        commandTask = Task { [weak self] in
            guard let self, token == self.generation, !Task.isCancelled else { return }
            await self.onAnswer?(answer, question)
            guard token == self.generation else { return }
            self.busy = false
            self.commandTask = nil
            self.tick()
        }
    }

    private func failed() {
        guard guideID != nil, !stopped else { return }
        closeAudioWindow()
        pause()
        let delays: [TimeInterval] = [1, 2, 5]
        guard failures < delays.count else {
            stop()
            status = .paused
            return
        }
        retryAt = now() + delays[failures]
        failures += 1
    }

    private func matchedCommand(_ text: String) -> VoiceCommand? {
        if isAudioWindowOpen, !VoiceCommand.phrases.contains(where: { VoiceCommand.normalized($0) == VoiceCommand.normalized(text) }) { return nil }
        return VoiceCommand.match(text)
    }
}
