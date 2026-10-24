// Adapted from a prior prototype, used with permission.

import Foundation
import Combine
import OSLog

@MainActor
final class TaskPlannerEngine: ObservableObject {
    @Published private(set) var plannerState: TaskPlannerState = .idle
    @Published private(set) var conversation: [ConversationTurn] = []
    @Published private(set) var tripPlannerPracticeViewModel: TripPlannerPracticeViewModel?
    @Published private(set) var currentIntent: JourneyIntent = .empty
    @Published var liveTranscript: String = ""
    @Published var lastErrorMessage: String?
    @Published private(set) var hasCompletedAtLeastOneJourney = false
    @Published private(set) var latestBrainSource: BrainSource
    @Published private(set) var latestBrainLatencyMilliseconds: Int?
    @Published private(set) var isTyping = false
    @Published private(set) var latestVoice: String?

    @Published private(set) var isPreparingSpeech = false
    @Published private(set) var placeSuggestions: [String] = []
    @Published private(set) var suggestionTranscript = ""
    @Published private(set) var sttMilliseconds: Int?
    @Published private(set) var firstAudioMilliseconds: Int?
    private var speechEndedAt: TimeInterval?
    private var suggestionSlot: MissingSlot?
    private var spokenInput = false
    private var consecutiveInputFailures = 0
    private static let inputFailureLimit = 2
    private static let retryLine = "Sorry, I didn't catch that. Could you say it again?"
    private let permissionCheck: (() async -> Bool)?

    var suggestionQuestion: String {
        "Did you mean \(placeSuggestions.joined(separator: " or "))?"
    }

    var timingBadge: String {
        let stt = sttMilliseconds.map { "STT \($0) ms" } ?? "STT pending"
        let model = latestBrainLatencyMilliseconds.map { "model \($0) ms" } ?? "model n/a"
        let audio = firstAudioMilliseconds.map { String(format: "first audio %.2f s", Double($0) / 1000) } ?? "first audio pending"
        return "\(stt), \(model), \(audio)"
    }

    private let brain: TaskPlannerBrain
    private let voiceInput: VoiceInputService
    private let voiceOutput: VoiceOutputService
    private let permissions: PermissionsManager
    private let userName: String

    private var pendingClarification: MissingSlot?
    private var clarificationFailures = 0
    /// Guards against overlapping listen/speak loops if the user mashes buttons.
    private var sessionGeneration = 0
    private var guidanceSpeechGeneration = 0

    init(brain: TaskPlannerBrain,
         voiceInput: VoiceInputService,
         voiceOutput: VoiceOutputService,
         permissions: PermissionsManager,
         userName: String, permissionCheck: (() async -> Bool)? = nil) {
        self.brain = brain
        self.latestBrainSource = brain.initialSource
        self.voiceInput = voiceInput
        self.voiceOutput = voiceOutput
        self.permissions = permissions
        self.userName = userName
        self.permissionCheck = permissionCheck
        self.voiceOutput.onVoiceChanged = { [weak self] voice in self?.latestVoice = voice }
        self.voiceOutput.onPlaybackStarted = { [weak self] in self?.recordFirstAudio() }
    }

    // MARK: - Entry points

    func beginSession() {
        consecutiveInputFailures = 0
        sessionGeneration += 1
        voiceInput.stopListening()
        voiceOutput.stop()
        voiceInput.resetSession()
        clearTurn()
        let generation = sessionGeneration
        Task { await runGreeting(generation: generation) }
    }

    /// User tapped the orb from an idle state to speak again.
    func userTappedToTalk() {
        consecutiveInputFailures = 0
        sessionGeneration += 1
        voiceInput.stopListening()
        voiceOutput.stop()
        isTyping = false
        clearSuggestions()
        lastErrorMessage = nil
        let generation = sessionGeneration
        Task {
            await listenAndHandle(generation: generation)
        }
    }

    func useTypedInput() {
        if let suggestionSlot { pendingClarification = suggestionSlot }
        sessionGeneration += 1
        voiceInput.stopListening()
        voiceOutput.stop()
        clearSuggestions()
        clearTurn()
        isPreparingSpeech = false
        isTyping = true
        tripPlannerPracticeViewModel = nil
        liveTranscript = ""
        plannerState = .idle
        // Keep pendingClarification and its retry count when changing input mode.
    }

    func submitTypedInput(_ text: String) {
        let transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isTyping, !transcript.isEmpty, case .idle = plannerState else { return }
        sessionGeneration += 1
        let generation = sessionGeneration
        lastErrorMessage = nil
        clearSuggestions()
        clearTurn()
        spokenInput = false
        plannerState = .thinking
        Task { await receive(transcript: transcript, generation: generation) }
    }

    /// "cancel" — stops whatever NearMe is currently doing and returns to a
    /// neutral, tappable idle state rather than silently continuing.
    func cancelCurrentAction() {
        clearSuggestions()
        clearTurn()
        isPreparingSpeech = false
        sessionGeneration += 1
        isTyping = false
        voiceInput.stopListening()
        voiceOutput.stop()
        pendingClarification = nil
        clarificationFailures = 0
        currentIntent = .empty
        tripPlannerPracticeViewModel = nil
        plannerState = .idle
    }

    /// "end session" — stops everything for good. There's no separate "ended"
    /// screen in the mockups; the caller (SessionContainerView) navigates
    /// straight back to onboarding once this returns.
    func endSession() {
        clearSuggestions()
        clearTurn()
        isPreparingSpeech = false
        sessionGeneration += 1
        isTyping = false
        voiceInput.stopListening()
        voiceOutput.stop()
        tripPlannerPracticeViewModel = nil
        plannerState = .idle
    }

    // MARK: - Greeting

    private func runGreeting(generation: Int) async {
        guard isCurrent(generation) else { return }
        await speak("Hi, what can we help you with?", generation: generation, greeting: true)
        guard isCurrent(generation) else { return }
        await listenAndHandle(generation: generation)
    }

    private func ensurePermissions(generation: Int) async -> Bool {
        if let permissionCheck { return await permissionCheck() }
        let didPromptJustNow = !permissions.isFullyAuthorized
        if didPromptJustNow {
            await permissions.requestAll()
        }
        guard isCurrent(generation) else { return false }
        if !permissions.isFullyAuthorized {
            let error: VoiceInputError = permissions.microphoneAuthorized ? .speechPermissionDenied : .microphonePermissionDenied
            VoiceDiagnostics.log(error)
            lastErrorMessage = VoiceDiagnostics.message(for: error)
            plannerState = .idle
            return false
        }
        if didPromptJustNow {
            // Let audio hardware settle after the first permission dialogs before capture.
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return true
    }

    private func ensureOnDeviceSpeech(generation: Int) async -> Bool {
        isPreparingSpeech = true
        defer { if isCurrent(generation) { isPreparingSpeech = false } }
        do {
            try await voiceInput.prepareForListening()
            return isCurrent(generation)
        } catch {
            guard isCurrent(generation) else { return false }
            VoiceDiagnostics.log(error)
            if let error = error as? VoiceInputError, error.requiresTyping { useTypedInput() }
            else { plannerState = .idle }
            lastErrorMessage = VoiceDiagnostics.message(for: error)
            return false
        }
    }

    // MARK: - Core loop

    /// FIX: `updatesPlannerState` defaults to `true` for the plain voice loop
    /// (idle/listening/thinking screens, which rely on `.speaking(text)` to
    /// show the right orb state and subtitle). The two guided-walkthrough
    /// call sites below pass `false`: they set `plannerState = .guiding(step)`
    /// immediately before calling this, and `TripPlannerPracticeView` already shows
    /// its own caption via `viewModel.currentCaption` — so if this function
    /// were allowed to overwrite `plannerState` to `.speaking(text)` here, it
    /// would immediately un-set `.guiding`, and `SessionContainerView` would
    /// switch straight back to the plain voice screen before the simulated
    /// trip planner screen was ever actually visible. That was the root cause of the
    /// guided walkthrough never visibly appearing.
    private func speak(_ text: String, generation: Int, updatesPlannerState: Bool = true, greeting: Bool = false) async {
        guard isCurrent(generation) else { return }
        if updatesPlannerState {
            plannerState = .speaking(text)
        }
        conversation.append(ConversationTurn(speaker: .nearme, text: text))
        if voiceInput.isListening { voiceInput.stopListening() }
        // Yield to foreground speech before doing next-caption cache work.
        let speechGeneration = guidanceSpeechGeneration
        let prefetch = Task { [weak self] in
            await Task.yield()
            guard let self, self.isCurrent(generation), speechGeneration == self.guidanceSpeechGeneration, let step = self.tripPlannerPracticeViewModel?.step else { return }
            self.prefetchCaption(after: step)
        }
        if greeting { await voiceOutput.speakGreeting(text) }
        else { await voiceOutput.speak(text) }
        await prefetch.value
        latestVoice = voiceOutput.lastVoice
    }

    private func listenAndHandle(generation: Int) async {
        guard isCurrent(generation) else { return }
        if isTyping {
            plannerState = .idle
            return
        }
        guard await ensureOnDeviceSpeech(generation: generation), isCurrent(generation),
              await ensurePermissions(generation: generation), isCurrent(generation) else { return }
        lastErrorMessage = nil
        plannerState = .listening
        liveTranscript = ""
        speechEndedAt = nil
        voiceInput.onSpeechEnd = { [weak self] transcript in
            guard let self, self.isCurrent(generation) else { return }
            self.clearTurn()
            self.liveTranscript = transcript
            self.speechEndedAt = self.voiceInput.lastTurn.endedAt
            self.plannerState = .thinking
        }

        do {
            let transcript = try await voiceInput.startListening { [weak self] partial in
                guard let self, self.isCurrent(generation) else { return }
                self.liveTranscript = partial
            }
            guard isCurrent(generation) else { return }
            consecutiveInputFailures = 0
            if speechEndedAt == nil { clearTurn() }
            liveTranscript = transcript
            speechEndedAt = voiceInput.lastTurn.endedAt ?? ProcessInfo.processInfo.systemUptime
            sttMilliseconds = elapsedSinceSpeechEnd()
            VoiceDiagnostics.logger.info("STT ms=\(self.sttMilliseconds ?? 0)")
            plannerState = .thinking
            spokenInput = true
            // Publish the final transcript before starting extraction.
            await Task.yield()
            await receive(transcript: transcript, generation: generation)
        } catch VoiceInputError.noSpeechDetected {
            VoiceDiagnostics.log(VoiceInputError.noSpeechDetected)
            guard isCurrent(generation) else { return }
            consecutiveInputFailures = 0
            lastErrorMessage = VoiceDiagnostics.message(for: VoiceInputError.noSpeechDetected)
            await speak(Self.retryLine, generation: generation)
            guard isCurrent(generation) else { return }
            await listenAndHandle(generation: generation)
        } catch {
            VoiceDiagnostics.log(error)
            guard isCurrent(generation) else { return }
            if let inputError = error as? VoiceInputError,
               inputError.requiresTyping {
                useTypedInput()
                lastErrorMessage = VoiceDiagnostics.message(for: error)
            } else if !(error is CancellationError) {
                consecutiveInputFailures += 1
                if consecutiveInputFailures >= Self.inputFailureLimit {
                    voiceInput.stopListening()
                    plannerState = .idle
                    lastErrorMessage = VoiceDiagnostics.message(for: error)
                    return
                }
                await speak(Self.retryLine, generation: generation)
                guard isCurrent(generation) else { return }
                await listenAndHandle(generation: generation)
            }
        }
    }

    private func receive(transcript: String, generation: Int) async {
        guard isCurrent(generation) else { return }
        lastErrorMessage = nil
        VoiceDiagnostics.logger.debug("User input: \(transcript, privacy: .private)")
        conversation.append(ConversationTurn(speaker: .user, text: transcript))
        await handle(transcript: transcript, generation: generation)
    }

    private func handle(transcript: String, generation: Int) async {
        guard isCurrent(generation) else { return }
        plannerState = .thinking

        do {
            if let missing = pendingClarification {
                if spokenInput, needsSuggestion(transcript) {
                    await suggest(transcript, for: missing, generation: generation)
                    return
                }
                let answer = try await brain.extractPlace(from: transcript, for: missing)
                guard isCurrent(generation) else { return }
                latestBrainSource = answer.source
                latestBrainLatencyMilliseconds = answer.latencyMilliseconds
                guard let place = answer.value?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty else {
                    clarificationFailures += 1
                    let question: String
                    if clarificationFailures == 1 {
                        question = "Sorry, which station or suburb?"
                    } else {
                        pendingClarification = nil
                        clarificationFailures = 0
                        currentIntent = .empty
                        question = "Let's start again. Where would you like to go?"
                    }
                    await speak(question, generation: generation)
                    guard isCurrent(generation) else { return }
                    await listenAndHandle(generation: generation)
                    return
                }
                pendingClarification = nil
                clarificationFailures = 0
                currentIntent = currentIntent.filling(missing, with: place)
                await proceedAfterIntentUpdate(generation: generation)
                return
            }

            let answer = try await brain.extractIntent(from: transcript)
            guard isCurrent(generation) else { return }
            latestBrainSource = answer.source
            latestBrainLatencyMilliseconds = answer.latencyMilliseconds
            let extracted = answer.value

            guard extracted.kind == .planJourney else {
                await speak("I can help you use a trip planner practice app. Try saying, \"I need to get to Town Hall\".", generation: generation)
                guard isCurrent(generation) else { return }
                await listenAndHandle(generation: generation)
                return
            }

            currentIntent = extracted
            await proceedAfterIntentUpdate(generation: generation)
        } catch {
            guard isCurrent(generation) else { return }
            // Same reasoning as the listening catch block above — keep this
            // user-facing, not the raw thrown error's description.
            lastErrorMessage = "I had trouble understanding that. Let's try again."
            await speak("Sorry, I had trouble understanding that. Could you try again?", generation: generation)
            guard isCurrent(generation) else { return }
            await listenAndHandle(generation: generation)
        }
    }

    private func proceedAfterIntentUpdate(generation: Int) async {
        guard isCurrent(generation) else { return }

        // With neither place supplied, ask where the person wants to go first.
        if let missing = (currentIntent.origin == nil && currentIntent.destination == nil
                          ? MissingSlot.destination : currentIntent.firstMissingSlot) {
            pendingClarification = missing
            clarificationFailures = 0
            latestBrainSource = .template
            await speak(PlannerTemplates.question(for: missing), generation: generation)
            guard isCurrent(generation) else { return }
            await listenAndHandle(generation: generation)
        } else {
            await openPracticeAndGuide(generation: generation)
        }
    }

    // MARK: - Opening practice + guided walkthrough

    private func openPracticeAndGuide(generation: Int) async {
        guard isCurrent(generation) else { return }
        latestBrainSource = .template
        await speak(PlannerTemplates.confirmation(for: currentIntent), generation: generation)
        guard isCurrent(generation) else { return }

        plannerState = .openingApp
        // Brief pause, then hand over to the trip planner practice walkthrough.
        try? await Task.sleep(nanoseconds: 900_000_000)
        guard isCurrent(generation) else { return }

        let simulation = TripPlannerPracticeViewModel(intent: currentIntent)
        simulation.onStepAdvanced = { [weak self] step in
            guard let self else { return }
            self.guidanceSpeechGeneration += 1
            let speechGeneration = self.guidanceSpeechGeneration
            Task { await self.handleGuidanceAdvanced(step, generation: generation, speechGeneration: speechGeneration) }
        }
        tripPlannerPracticeViewModel = simulation
        plannerState = .guiding(.forYouOpened)
        await speak(PracticeStep.forYouOpened.caption(origin: currentIntent.origin ?? "", destination: currentIntent.destination ?? ""), generation: generation, updatesPlannerState: false)
    }

    private func handleGuidanceAdvanced(_ step: PracticeStep, generation: Int, speechGeneration: Int) async {
        guard isCurrent(generation), tripPlannerPracticeViewModel?.step == step,
              speechGeneration == guidanceSpeechGeneration else { return }
        plannerState = .guiding(step)
        let caption = step.caption(origin: currentIntent.origin ?? "", destination: currentIntent.destination ?? "")
        await speak(caption, generation: generation, updatesPlannerState: false)
        guard isCurrent(generation), tripPlannerPracticeViewModel?.step == step,
              speechGeneration == guidanceSpeechGeneration else { return }

        if step == .showingResults {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard isCurrent(generation), speechGeneration == guidanceSpeechGeneration else { return }
            tripPlannerPracticeViewModel = nil
            currentIntent = .empty
            hasCompletedAtLeastOneJourney = true
            await listenAndHandle(generation: generation)
        }
    }

    func stopPracticeSpeech() {
        guard tripPlannerPracticeViewModel != nil else { return }
        guidanceSpeechGeneration += 1
        voiceOutput.stop()
    }

    private func needsSuggestion(_ text: String) -> Bool {
        (voiceInput.lastTurn.confidence ?? 1) < PracticeVocabulary.confidenceThreshold || !PracticeVocabulary.containsPlace(text)
    }

    private func suggest(_ place: String, for slot: MissingSlot, generation: Int) async {
        suggestionSlot = slot
        suggestionTranscript = place
        placeSuggestions = PracticeVocabulary.closestPlaces(to: place)
        latestBrainSource = .template
        await speak(suggestionQuestion, generation: generation)
        guard isCurrent(generation), suggestionSlot != nil else { return }
        plannerState = .idle
    }

    func chooseSuggestedPlace(_ place: String) {
        guard let slot = suggestionSlot, placeSuggestions.contains(place) else { return }
        sessionGeneration += 1
        voiceOutput.stop()
        currentIntent.intent = .planJourney
        currentIntent = currentIntent.filling(slot, with: place)
        pendingClarification = nil
        clarificationFailures = 0
        placeSuggestions = []
        suggestionSlot = nil
        let generation = sessionGeneration
        Task {
            await proceedAfterIntentUpdate(generation: generation)
        }
    }

    func retrySuggestedPlace() {
        guard let slot = suggestionSlot else { return }
        pendingClarification = slot
        if slot == .origin { currentIntent.origin = nil } else { currentIntent.destination = nil }
        clearSuggestions()
        userTappedToTalk()
    }

    private func clearSuggestions() {
        placeSuggestions = []
        suggestionSlot = nil
        suggestionTranscript = ""
    }

    private func clearTurn() {
        speechEndedAt = nil
        sttMilliseconds = nil
        firstAudioMilliseconds = nil
        latestBrainLatencyMilliseconds = nil
    }

    private func elapsedSinceSpeechEnd() -> Int? {
        speechEndedAt.map { max(0, Int((ProcessInfo.processInfo.systemUptime - $0) * 1000)) }
    }

    private func recordFirstAudio() {
        guard firstAudioMilliseconds == nil, let elapsed = elapsedSinceSpeechEnd() else { return }
        firstAudioMilliseconds = elapsed
        VoiceDiagnostics.logger.info("First audio ms=\(elapsed)")
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == sessionGeneration
    }

    private func prefetchCaption(after step: PracticeStep) {
        guard let next = step.next else { return }
        voiceOutput.prefetch(next.caption(origin: currentIntent.origin ?? "", destination: currentIntent.destination ?? ""))
    }

    func repeatPracticeCaption(slower: Bool = false) {
        guard let step = tripPlannerPracticeViewModel?.step else { return }
        voiceOutput.setSlower(slower)
        let generation = sessionGeneration
        guidanceSpeechGeneration += 1
        let speechGeneration = guidanceSpeechGeneration
        Task { await handleGuidanceAdvanced(step, generation: generation, speechGeneration: speechGeneration) }
    }
}
