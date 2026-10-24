import Foundation
import OSLog

@MainActor
protocol CommandSpeechInput: AnyObject {
    var onResult: ((String, Bool) -> Void)? { get set }
    var onFailure: (() -> Void)? { get set }
    var onAudioHint: (() -> Void)? { get set }
    var otherAudio: Bool { get }
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
    var isHandlingCommand: Bool { busy }
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
    private var partialSince: TimeInterval = 0
    private var recognitionSince: TimeInterval = 0
    private var generation = 0
    private var commandTask: Task<Void, Never>?

    init(input: any CommandSpeechInput, now: @escaping () -> TimeInterval) {
        self.input = input
        self.now = now
        input.onResult = { [weak self] text, final in self?.receive(text, final: final) }
        input.onFailure = { [weak self] in self?.failed() }
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
        if value { pause() }
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

    func stop() {
        generation += 1
        commandTask?.cancel()
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
        if speaking || input.otherAudio || busy {
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
        guard !speaking, !input.otherAudio, !busy, now() >= settleUntil else { return }
        if !recognizing {
            do {
                try input.startRecognition()
                recognizing = true
                recognitionSince = now()
                retryAt = nil
            } catch { failed(); return }
        }
        if !partial.isEmpty, now() - partialSince >= 0.6, let command = VoiceCommand.match(partial) {
            accept(command)
        } else if now() - recognitionSince >= 55 {
            failed()
        }
    }

    private func receive(_ text: String, final: Bool) {
        guard recognizing, !speaking, !busy, !input.otherAudio, now() >= settleUntil else { return }
        let normalized = VoiceCommand.normalized(text)
        if partial != normalized { partial = normalized; partialSince = now() }
        if final {
            if let command = VoiceCommand.match(text) { accept(command) }
            else { pause(); tick() } // Other speech is discarded silently.
        }
    }

    private func accept(_ command: VoiceCommand) {
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
        input.pauseRecognition()
    }

    private func failed() {
        guard guideID != nil, !stopped else { return }
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
}
