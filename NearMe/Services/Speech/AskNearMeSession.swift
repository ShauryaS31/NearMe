import Foundation

@MainActor protocol AskCapturing: AnyObject {
    var onResult: ((String) -> Void)? { get set }
    var onFailure: (() -> Void)? { get set }
    var onSpeech: (() -> Void)? { get set }
    var onMediaChanged: (() -> Void)? { get set }
    var onRecognitionEnded: (() -> Void)? { get set }
    var otherAudio: Bool { get }
    func start() throws
    func resumeRecognition() throws
    func pauseRecognition()
    func finish()
    func stop()
}

@MainActor protocol AskActivityPresenting: AnyObject {
    var onDismiss: (() -> Void)? { get set }
    func start(id: UUID, expiresAt: Date) throws
    func update(_ state: AskWidgetState) async
    func end() async
}

nonisolated enum AskConversationPolicy {
    static let silence: TimeInterval = 45
    static let grace: TimeInterval = 20
    static let wait: TimeInterval = 90
    static let maximum: TimeInterval = 600
    static let response: TimeInterval = 60
    static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
    static func isStop(_ text: String) -> Bool {
        ["stop", "please stop", "stop please", "stop listening", "end", "end session", "goodbye"].contains(normalized(text))
    }
    static func isWait(_ text: String) -> Bool {
        ["wait", "please wait", "one minute", "wait a minute", "i'm still here", "i am still here",
         "give me a minute", "i still need you"].contains(normalized(text))
    }
}

/// Hardware remains owned during a bounded conversation, but recognition is
/// detached during thinking/output. Only an explicit new tap starts hardware.
@MainActor final class AskNearMeSession {
    private let input: any AskCapturing
    private let activity: any AskActivityPresenting
    private let allowed: () -> Bool
    private let prepare: () -> Void
    private let submit: (String) async -> AskPhase
    private let say: (String) async -> Void
    private let cancel: () -> Void
    private let interrupt: () -> Void
    private let publish: (AskWidgetState) -> Void
    private let now: () -> Date
    private let settle: () async throws -> Void
    private let sleep: (TimeInterval) async throws -> Void
    private var idleTask: Task<Void, Never>?
    private var maximumTask: Task<Void, Never>?
    private var work: Task<Void, Never>?
    private var idleRevision = 0
    private var operationRevision = 0
    private var externalSpeechRevision: Int?
    private var engineSpeaking = false
    private var hardwareStarted = false
    private var maximumDate: Date?
    private var idleDeadline: Date?
    private var needsApp = false
    private var recognitionRetries = 0
    private(set) var didCheckIn = false
    private(set) var awaitingCheckIn = false
    private(set) var state = AskWidgetState(phase: .ready)
    var isActive: Bool { state.sessionID != nil }

    init(input: any AskCapturing, activity: any AskActivityPresenting,
         allowed: @escaping () -> Bool, prepare: @escaping () -> Void,
         submit: @escaping (String) async -> AskPhase, say: @escaping (String) async -> Void,
         cancel: @escaping () -> Void, publish: @escaping (AskWidgetState) -> Void,
         now: @escaping () -> Date, settle: (() async throws -> Void)? = nil,
         sleep: ((TimeInterval) async throws -> Void)? = nil, interrupt: (() -> Void)? = nil) {
        self.input = input; self.activity = activity; self.allowed = allowed
        self.prepare = prepare; self.submit = submit; self.say = say; self.cancel = cancel
        self.publish = publish; self.now = now
        self.interrupt = interrupt ?? {}
        self.settle = settle ?? { try await Task.sleep(for: .milliseconds(200)) }
        self.sleep = sleep ?? { try await Task.sleep(for: .seconds($0)) }
        input.onResult = { [weak self] text in
            guard let self, let id = self.state.sessionID,
                  self.state.phase == .listening || self.state.phase == .finishing else { return }
            self.work = Task { await self.received(text, id: id) }
        }
        input.onSpeech = { [weak self] in
            guard let self, let id = self.state.sessionID, self.state.phase == .listening else { return }
            var next = self.state; next.expiresAt = self.expiry(AskConversationPolicy.silence)
            self.set(next)
            self.scheduleIdle(id: id, seconds: AskConversationPolicy.silence)
            Task { await self.activity.update(next) }
        }
        input.onFailure = { [weak self] in self?.fail() }
        input.onRecognitionEnded = { [weak self] in
            guard let self, let id = self.state.sessionID, self.state.phase == .listening else { return }
            self.recognitionRetries += 1
            guard self.recognitionRetries <= 2 else { self.fail(); return }
            let remaining = self.quietTimeRemaining()
            self.work = Task {
                await self.updatePhase(.starting, id: id, seconds: remaining)
                await self.listen(id: id, seconds: remaining)
            }
        }
        input.onMediaChanged = { [weak self] in
            guard let self, let id = self.state.sessionID else { return }
            if self.input.otherAudio, self.state.phase == .listening {
                self.input.pauseRecognition()
                self.work = Task { await self.listen(id: id, seconds: AskConversationPolicy.wait) }
            } else if !self.input.otherAudio, self.state.phase == .paused {
                self.work = Task { await self.listen(id: id, seconds: AskConversationPolicy.silence) }
            }
        }
        activity.onDismiss = { [weak self] in
            guard let self, let id = self.state.sessionID else { return }
            self.work = Task { await self.stop(id: id) }
        }
    }

    func start() async {
        guard !isActive else { return }
        guard allowed() else { set(AskWidgetState(phase: .setup)); return }
        let id = UUID()
        engineSpeaking = false; hardwareStarted = false
        maximumDate = now().addingTimeInterval(AskConversationPolicy.maximum)
        didCheckIn = false; awaitingCheckIn = false; recognitionRetries = 0; needsApp = false
        set(AskWidgetState(phase: .starting, sessionID: id,
                           expiresAt: now().addingTimeInterval(AskConversationPolicy.silence)))
        do {
            try activity.start(id: id, expiresAt: expiry(AskConversationPolicy.silence))
            prepare()
            try await settle()
            guard state.sessionID == id else { return }
            guard allowed() else { await stop(id: id, phase: .setup); return }
            try input.start()
            hardwareStarted = true
            maximumTask = Task { [weak self] in
                guard let self else { return }
                do { try await self.sleep(AskConversationPolicy.maximum) } catch { return }
                await self.goodbye(id: id)
            }
            await listen(id: id, seconds: AskConversationPolicy.silence)
        } catch { await stop(id: id, phase: .failed) }
    }

    func finish(id: UUID) {
        guard state.sessionID == id, state.phase == .listening else { return }
        var next = state; next.phase = .finishing; set(next)
        input.finish()
    }

    func stop(id: UUID, phase: AskPhase = .stopped) async {
        guard state.sessionID == id else { return }
        set(AskWidgetState(phase: phase))
        operationRevision += 1; externalSpeechRevision = nil
        engineSpeaking = false; hardwareStarted = false
        input.stop(); cancel()
        idleRevision += 1
        idleTask?.cancel(); idleTask = nil
        maximumTask?.cancel(); maximumTask = nil
        work?.cancel(); work = nil
        await activity.end()
    }

    /// Explicit timer callback for deterministic tests. Scheduled callbacks compare
    /// revisions, so new speech invalidates an already queued quiet timeout.
    func silenceElapsed(id: UUID) async {
        guard state.sessionID == id else { return }
        if state.phase == .paused { await stop(id: id); return }
        guard state.phase == .listening else { await stop(id: id, phase: .failed); return }
        if didCheckIn { await goodbye(id: id); return }
        didCheckIn = true
        awaitingCheckIn = true
        operationRevision += 1
        let operation = operationRevision
        input.pauseRecognition()
        await updatePhase(.checking, id: id, seconds: AskConversationPolicy.response)
        guard state.sessionID == id, operationRevision == operation, state.phase == .checking else { return }
        await say("Do you still need me?")
        guard operationRevision == operation else { return }
        await listen(id: id, seconds: AskConversationPolicy.grace, operation: operation)
    }

    private func received(_ text: String, id: UUID) async {
        guard state.sessionID == id, state.phase == .listening || state.phase == .finishing else { return }
        operationRevision += 1
        let operation = operationRevision
        input.pauseRecognition()
        idleRevision += 1; idleTask?.cancel()
        let transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if AskConversationPolicy.isStop(transcript) { await goodbye(id: id); return }
        guard !transcript.isEmpty else { await listen(id: id, seconds: quietTimeRemaining()); return }
        recognitionRetries = 0
        let normalized = AskConversationPolicy.normalized(transcript)
        let checkInYes = awaitingCheckIn && ["yes", "yes please"].contains(normalized)
        let checkInNo = awaitingCheckIn && ["no", "no thanks", "no thank you"].contains(normalized)
        awaitingCheckIn = false
        if checkInNo { await goodbye(id: id); return }
        await updatePhase(.answering, id: id, seconds: AskConversationPolicy.response)
        guard state.sessionID == id, operationRevision == operation, state.phase == .answering else { return }
        if AskConversationPolicy.isWait(transcript) || checkInYes {
            await say("Take your time. I'm here.")
            guard operationRevision == operation else { return }
            await listen(id: id, seconds: AskConversationPolicy.wait, operation: operation)
            return
        }
        let completion = await submit(transcript)
        guard state.sessionID == id, operationRevision == operation, state.phase == .answering else { return }
        needsApp = completion == .needsApp
        await listen(id: id, seconds: AskConversationPolicy.silence, operation: operation)
    }

    private func listen(id: UUID, seconds: TimeInterval, operation: Int? = nil) async {
        let expected = operation ?? operationRevision
        guard state.sessionID == id, state.phase != .ending, expected == operationRevision, !Task.isCancelled else { return }
        guard hardwareStarted, !engineSpeaking else { return }
        do {
            try await settle()
            guard expected == operationRevision, state.phase != .ending else { return }
            guard hardwareStarted, !engineSpeaking else { return }
            guard state.sessionID == id, allowed() else {
                await stop(id: id, phase: .setup); return
            }
            if input.otherAudio {
                input.pauseRecognition()
                await updatePhase(.paused, id: id, seconds: AskConversationPolicy.wait)
                return
            }
            try input.resumeRecognition()
            var next = state
            next.phase = .listening
            if next.startedAt == nil { next.startedAt = now() }
            next.continueInApp = needsApp
            next.expiresAt = expiry(seconds)
            set(next)
            scheduleIdle(id: id, seconds: seconds)
            await activity.update(next)
        } catch { await stop(id: id, phase: .failed) }
    }

    func goodbye(id: UUID) async {
        guard state.sessionID == id, state.phase != .ending else { return }
        operationRevision += 1; externalSpeechRevision = nil
        let operation = operationRevision
        input.pauseRecognition()
        interrupt()
        await updatePhase(.ending, id: id, seconds: 8)
        guard state.sessionID == id, operationRevision == operation, state.phase == .ending else { return }
        await say("I'll stop listening now. Goodbye.")
        await stop(id: id)
    }

    /// Covers every engine playback path, including a guide update or Done intent
    /// that speaks outside the submitted widget request.
    func externalSpeechChanged(_ speaking: Bool) {
        engineSpeaking = speaking
        guard let id = state.sessionID else { return }
        if speaking, state.phase == .starting || state.phase == .listening || state.phase == .paused {
            input.pauseRecognition()
            operationRevision += 1
            externalSpeechRevision = operationRevision
            var next = state; next.phase = .answering; next.expiresAt = expiry(AskConversationPolicy.response)
            set(next)
            scheduleIdle(id: id, seconds: AskConversationPolicy.response)
            Task { await activity.update(next) }
        } else if !speaking, let operation = externalSpeechRevision {
            externalSpeechRevision = nil
            // Startup will attach recognition after hardware succeeds. A playback
            // completion during the initial settle must not race that activation.
            guard hardwareStarted else { return }
            work = Task { await self.listen(id: id, seconds: AskConversationPolicy.silence, operation: operation) }
        }
    }

    private func updatePhase(_ phase: AskPhase, id: UUID, seconds: TimeInterval) async {
        guard state.sessionID == id else { return }
        var next = state; next.phase = phase; next.expiresAt = expiry(seconds)
        set(next)
        scheduleIdle(id: id, seconds: seconds)
        await activity.update(next)
    }

    private func scheduleIdle(id: UUID, seconds: TimeInterval) {
        idleRevision += 1
        let revision = idleRevision
        idleDeadline = expiry(seconds)
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            guard let self else { return }
            do { try await self.sleep(seconds) } catch { return }
            guard self.idleRevision == revision, self.state.sessionID == id else { return }
            self.idleTask = nil
            await self.silenceElapsed(id: id)
        }
    }

    private func expiry(_ seconds: TimeInterval) -> Date {
        min(now().addingTimeInterval(seconds), maximumDate ?? now().addingTimeInterval(seconds))
    }
    private func quietTimeRemaining() -> TimeInterval {
        max(0, (idleDeadline ?? now()).timeIntervalSince(now()))
    }
    private func fail() {
        guard let id = state.sessionID else { return }
        work = Task { await self.stop(id: id, phase: .failed) }
    }
    private func set(_ value: AskWidgetState) { state = value; publish(value) }
}
