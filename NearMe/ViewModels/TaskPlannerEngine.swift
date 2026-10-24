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
    @Published private(set) var isVoiceOutputActive = false
    @Published private(set) var isStartingListening = false
    @Published private(set) var coach: CoachSession?
    @Published private(set) var isHome = true
    private let guides: [Guide]
    private let helpRouter: any HelpRouting
    private let coachService: CoachModelService
    private let coachStore: CoachProgressStore
    private var tripRouteActive = false
    private var preparedStep: (index: Int, task: Task<BrainAnswer<String>, Never>)?
    private var wasBackgrounded = false
    private var playbackGeneration = 0
    private let settleBeforeListening: () async throws -> Void

    @Published private(set) var isPreparingSpeech = false
    @Published private(set) var placeSuggestions: [String] = []
    @Published private(set) var suggestionTranscript = ""
    @Published private(set) var sttMilliseconds: Int?
    @Published private(set) var firstAudioMilliseconds: Int?
    private var speechEndedAt: TimeInterval?
    @Published private var suggestionSlot: MissingSlot?
    private var suggestionPlace: String?
    private var spokenInput = false
    private var consecutiveInputFailures = 0
    private static let inputFailureLimit = 2
    private static let retryLine = "Sorry, I didn't catch that. Could you say it again?"
    private let permissionCheck: (() async -> Bool)?

    var suggestionQuestion: String {
        placeSuggestions.isEmpty
            ? "Did you say \(suggestionTranscript)?"
            : "Did you mean \(placeSuggestions.joined(separator: " or "))?"
    }

    var isShowingPlaceSuggestions: Bool { suggestionSlot != nil }

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
         userName: String, permissionCheck: (() async -> Bool)? = nil,
         settleBeforeListening: (() async throws -> Void)? = nil,
         guides: [Guide]? = nil, helpRouter: (any HelpRouting)? = nil,
         coachService: CoachModelService? = nil, coachStore: CoachProgressStore? = nil) {
        let library = guides ?? GuideLibrary.bundled()
        let service = coachService ?? CoachModelService.makeDefault()
        self.guides = library
        self.coachService = service
        self.helpRouter = helpRouter ?? HelpRouter(guides: library, service: service)
        self.coachStore = coachStore ?? CoachProgressStore()
        self.brain = brain
        self.latestBrainSource = brain.initialSource
        self.voiceInput = voiceInput
        self.voiceOutput = voiceOutput
        self.permissions = permissions
        self.userName = userName
        self.permissionCheck = permissionCheck
        self.settleBeforeListening = settleBeforeListening ?? {
            try await Task.sleep(for: .seconds(SpeechSilenceRule.playbackSettle))
        }
        self.voiceInput.acceptsTranscript = { [weak self] in
            guard let self else { return false }
            return !self.isVoiceOutputActive && !self.isStartingListening
        }
        self.voiceOutput.onVoiceChanged = { [weak self] voice in self?.latestVoice = voice }
        self.voiceOutput.onPlaybackStarted = { [weak self] in self?.recordFirstAudio() }
    }

    // MARK: - Entry points

    func beginSession() {
        isHome = false
        consecutiveInputFailures = 0
        sessionGeneration += 1
        voiceInput.stopListening()
        stopOutput()
        voiceInput.resetSession()
        clearTurn()
        let generation = sessionGeneration
        Task { await runGreeting(generation: generation) }
    }

    /// A second tap finishes the turn; speaking can be interrupted immediately.
    func userTappedToTalk() {
        isHome = false
        if plannerState == .listening {
            plannerState = .finishing
            voiceInput.finishListening()
            return
        }
        guard plannerState != .finishing, plannerState != .thinking, !isStartingListening else { return }
        if let suggestionSlot { pendingClarification = suggestionSlot }
        consecutiveInputFailures = 0
        sessionGeneration += 1
        guidanceSpeechGeneration += 1
        voiceInput.stopListening()
        stopOutput()
        plannerState = .idle
        isStartingListening = true
        isTyping = false
        clearSuggestions()
        lastErrorMessage = nil
        let generation = sessionGeneration
        Task {
            await listenAndHandle(generation: generation)
        }
    }

    func useTypedInput() {
        isHome = false
        if let suggestionSlot { pendingClarification = suggestionSlot }
        sessionGeneration += 1
        voiceInput.stopListening()
        stopOutput()
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
        clearCoach()
        isHome = true
        tripRouteActive = false
        clearSuggestions()
        clearTurn()
        isPreparingSpeech = false
        sessionGeneration += 1
        isTyping = false
        voiceInput.stopListening()
        stopOutput()
        pendingClarification = nil
        clarificationFailures = 0
        currentIntent = .empty
        tripPlannerPracticeViewModel = nil
        plannerState = .idle
    }

    /// End all guidance and return to the help home screen.
    func endSession() {
        clearCoach()
        isHome = true
        tripRouteActive = false
        pendingClarification = nil
        currentIntent = .empty
        clearSuggestions()
        clearTurn()
        isPreparingSpeech = false
        sessionGeneration += 1
        isTyping = false
        voiceInput.stopListening()
        stopOutput()
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

    /// Plain voice turns publish their spoken text through the planner state.
    /// Practice captions keep the guiding state and use the practice's own caption.
    private func speak(_ text: String, generation: Int, updatesPlannerState: Bool = true, greeting: Bool = false) async {
        guard isCurrent(generation) else { return }
        if updatesPlannerState {
            plannerState = .speaking(text)
        }
        conversation.append(ConversationTurn(speaker: .nearme, text: text))
        if voiceInput.isListening { voiceInput.stopListening() }
        playbackGeneration += 1
        let playback = playbackGeneration
        isVoiceOutputActive = true
        defer { if playback == playbackGeneration { isVoiceOutputActive = false } }
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
        isStartingListening = true
        defer { if isCurrent(generation) { isStartingListening = false } }
        guard await ensureOnDeviceSpeech(generation: generation), isCurrent(generation),
              await ensurePermissions(generation: generation), isCurrent(generation) else { return }
        guard !isVoiceOutputActive else { return }
        do { try await settleBeforeListening() } catch { return }
        guard isCurrent(generation), !isVoiceOutputActive, !Task.isCancelled else { return }
        isStartingListening = false
        lastErrorMessage = nil
        plannerState = .listening
        liveTranscript = ""
        speechEndedAt = nil
        voiceInput.onSpeechEnd = { [weak self] transcript in
            guard let self, self.isCurrent(generation), !self.isVoiceOutputActive else { return }
            self.clearTurn()
            self.liveTranscript = transcript
            self.speechEndedAt = self.voiceInput.lastTurn.endedAt
            self.plannerState = .finishing
        }

        do {
            let transcript = try await voiceInput.startListening { [weak self] partial in
                guard let self, self.isCurrent(generation), !self.isVoiceOutputActive,
                      !self.isStartingListening else { return }
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
            await speak(VoiceDiagnostics.message(for: VoiceInputError.noSpeechDetected), generation: generation)
            guard isCurrent(generation) else { return }
            plannerState = .idle
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
        if coach != nil {
            await handleCoachCommand(CoachCommand.parse(transcript), generation: generation)
            return
        }
        if tripPlannerPracticeViewModel != nil {
            let command = transcript.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
            switch command {
            case "stop", "end": cancelCurrentAction()
            case "slower": repeatPracticeCaption(slower: true)
            default: repeatPracticeCaption()
            }
            return
        }
        if !tripRouteActive {
            let answer = await helpRouter.route(transcript)
            guard isCurrent(generation) else { return }
            latestBrainSource = answer.source
            latestBrainLatencyMilliseconds = answer.latencyMilliseconds
            switch answer.value.route {
            case .practiceTripPlanner:
                tripRouteActive = true
            case .guide(let id):
                if let guide = guides.first(where: { $0.id == id }) {
                    await startCoach(guide: guide, request: transcript, person: answer.value.person, generation: generation)
                } else {
                    await startGeneral(request: transcript, generation: generation)
                }
                return
            case .general:
                await startGeneral(request: transcript, generation: generation)
                return
            }
        }
        // Journey extraction and all slot questions are reachable only after a trip route.
        // An infinitive in "want to practise/plan a trip" is not a destination.
        let journeyRequest = transcript.replacingOccurrences(of: #"(?i)\bto\s+(?:practi[cs]e|plan(?:ning)?)\b"#,
                                                            with: "", options: .regularExpression)
        await handle(transcript: journeyRequest, generation: generation)
    }

    private func handle(transcript: String, generation: Int) async {
        guard isCurrent(generation), tripRouteActive else { return }
        plannerState = .thinking

        do {
            if let missing = pendingClarification {
                let answer = try await brain.extractPlace(from: transcript, for: missing)
                guard isCurrent(generation) else { return }
                latestBrainSource = answer.source
                latestBrainLatencyMilliseconds = answer.latencyMilliseconds
                let extractedPlace = PlaceNormalization.normalize(answer.value)
                if spokenInput, needsSuggestion(extractedPlace) {
                    await suggest(transcript, extractedPlace: extractedPlace, for: missing, generation: generation)
                    return
                }
                guard let place = extractedPlace else {
                    clarificationFailures += 1
                    let question: String
                    if clarificationFailures == 1 {
                        question = "Sorry, which station or suburb?"
                    } else {
                        pendingClarification = nil
                        clarificationFailures = 0
                        currentIntent = .empty
                        tripRouteActive = false
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
            let extracted = answer.value.normalizingPlaces()

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
            // A voice interruption changes the session generation but keeps this practice.
            self.stopPracticeSpeech()
            let generation = self.sessionGeneration
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
            tripRouteActive = false
            isHome = true
            plannerState = .idle
        }
    }

    func stopPracticeSpeech() {
        guard let practice = tripPlannerPracticeViewModel else { return }
        sessionGeneration += 1
        guidanceSpeechGeneration += 1
        voiceInput.stopListening()
        stopOutput()
        isPreparingSpeech = false
        lastErrorMessage = nil
        plannerState = .guiding(practice.step)
    }

    private func stopOutput() {
        playbackGeneration += 1
        voiceOutput.stop()
        isVoiceOutputActive = false
        isStartingListening = false
    }

    private func needsSuggestion(_ extractedPlace: String?) -> Bool {
        (voiceInput.lastTurn.confidence ?? 1) < PracticeVocabulary.confidenceThreshold || extractedPlace == nil
    }

    private func suggest(_ transcript: String, extractedPlace: String?, for slot: MissingSlot, generation: Int) async {
        suggestionSlot = slot
        suggestionTranscript = transcript
        // Keep the extracted words exactly; with no extraction, keep the cleaned transcript.
        suggestionPlace = PlaceNormalization.normalize(extractedPlace)
            ?? PlaceNormalization.normalize(transcript.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)))
        placeSuggestions = PracticeVocabulary.closestPlaces(to: extractedPlace ?? transcript)
        latestBrainSource = .template
        await speak(suggestionQuestion, generation: generation)
        guard isCurrent(generation), suggestionSlot != nil else { return }
        plannerState = .idle
    }

    func chooseSuggestedPlace(_ place: String) {
        guard placeSuggestions.contains(place) else { return }
        acceptSuggestedPlace(place)
    }

    func keepSuggestedPlace() {
        guard suggestionSlot != nil else { return }
        acceptSuggestedPlace(suggestionPlace)
    }

    private func acceptSuggestedPlace(_ place: String?) {
        guard let slot = suggestionSlot else { return }
        sessionGeneration += 1
        stopOutput()
        currentIntent.intent = .planJourney
        currentIntent = currentIntent.filling(slot, with: PlaceNormalization.normalize(place) ?? "")
        pendingClarification = nil
        clarificationFailures = 0
        clearSuggestions()
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
        suggestionPlace = nil
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
        guard let practice = tripPlannerPracticeViewModel else { return }
        stopPracticeSpeech()
        voiceOutput.setSlower(slower)
        let generation = sessionGeneration
        let speechGeneration = guidanceSpeechGeneration
        Task {
            guard self.isCurrent(generation), speechGeneration == self.guidanceSpeechGeneration else { return }
            // Repeating a caption must not advance or finish the practice, even on its last step.
            await self.speak(practice.currentCaption, generation: generation, updatesPlannerState: false)
        }
    }

    // MARK: - Guide and general coach

    func startPractice() {
        cancelCurrentAction()
        useTypedInput()
        // Even the practice card goes through the router before journey extraction.
        submitTypedInput("I want to practise planning a train trip")
    }

    private func startCoach(guide: Guide, request: String, person: String?, generation: Int) async {
        voiceOutput.setSlower(false)
        coach = CoachSession(guide: guide, request: request, person: PersonNormalization.normalize(person),
                             generalSteps: [], stepIndex: 0, text: CoachText.fallback(step: guide.steps[0], person: person))
        if let coach { coachStore.save(coach) }
        await presentCoachStep(generation: generation)
    }

    private func startGeneral(request: String, generation: Int) async {
        let answer = await coachService.general(request: request)
        guard isCurrent(generation) else { return }
        latestBrainSource = answer.source
        latestBrainLatencyMilliseconds = answer.latencyMilliseconds
        voiceOutput.setSlower(false)
        coachStore.clear()
        coach = CoachSession(guide: nil, request: request, person: nil, generalSteps: answer.value,
                             stepIndex: 0, text: answer.value.first ?? CoachText.generalFallback)
        await presentCoachStep(generation: generation)
    }

    func coachCommand(_ command: CoachCommand) {
        guard coach != nil else { return }
        lastErrorMessage = nil
        sessionGeneration += 1
        voiceInput.stopListening()
        stopOutput()
        let generation = sessionGeneration
        plannerState = .thinking
        Task { await self.handleCoachCommand(command, generation: generation) }
    }

    private func handleCoachCommand(_ command: CoachCommand?, generation: Int) async {
        guard isCurrent(generation), let session = coach else { return }
        switch command {
        case .stop:
            cancelCurrentAction()
        case .next:
            if session.stepIndex + 1 == session.count {
                preparedStep?.task.cancel()
                preparedStep = nil
                coach?.text = "That's it, you're done."
                coachStore.clear()
                await speak("That's it, you're done.", generation: generation)
                guard isCurrent(generation) else { return }
                cancelCurrentAction()
            } else {
                coach?.stepIndex += 1
                if let coach { coachStore.save(coach) }
                await presentCoachStep(generation: generation)
            }
        case .slower:
            coach?.slower = true
            voiceOutput.setSlower(true)
            await speakCoach(generation: generation)
        case .stuck:
            if let guide = session.guide {
                plannerState = .thinking
                let answer = await coachService.rewrite(request: session.request, guide: guide, index: session.stepIndex,
                                                        person: session.person, stuck: true)
                guard isCurrent(generation), coach?.id == session.id else { return }
                coach?.text = answer.value
                latestBrainSource = answer.source
                latestBrainLatencyMilliseconds = answer.latencyMilliseconds
            } else {
                plannerState = .thinking
                let answer = await coachService.generalStuck(step: session.generalSteps[session.stepIndex])
                guard isCurrent(generation), coach?.id == session.id else { return }
                coach?.text = answer.value
                latestBrainSource = answer.source
                latestBrainLatencyMilliseconds = answer.latencyMilliseconds
            }
            await speakCoach(generation: generation)
        case .repeatStep:
            await speakCoach(generation: generation)
        case nil:
            lastErrorMessage = "Try Done, Repeat, Slower, I'm stuck or Stop."
            plannerState = .idle
        }
    }

    private func presentCoachStep(generation: Int) async {
        guard let session = coach, isCurrent(generation) else { return }
        if let guide = session.guide {
            coach?.text = CoachText.fallback(step: guide.steps[session.stepIndex], person: session.person)
            plannerState = .thinking
            let answer: BrainAnswer<String>
            if let preparedStep, preparedStep.index == session.stepIndex {
                answer = await preparedStep.task.value
            } else {
                answer = await coachService.rewrite(request: session.request, guide: guide, index: session.stepIndex, person: session.person)
            }
            guard isCurrent(generation), coach?.id == session.id else { return }
            preparedStep = nil
            coach?.text = answer.value
            latestBrainSource = answer.source
            latestBrainLatencyMilliseconds = answer.latencyMilliseconds
            prepareNextCoachStep()
        } else {
            coach?.text = session.generalSteps[session.stepIndex]
        }
        await speakCoach(generation: generation)
    }

    private func prepareNextCoachStep() {
        guard let session = coach, let guide = session.guide, session.stepIndex + 1 < guide.steps.count else { return }
        let index = session.stepIndex + 1
        let service = coachService
        preparedStep?.task.cancel()
        preparedStep = (index, Task {
            await service.rewrite(request: session.request, guide: guide, index: index, person: session.person)
        })
    }

    private func speakCoach(generation: Int, welcome: Bool = false) async {
        guard let session = coach, isCurrent(generation) else { return }
        voiceOutput.setSlower(session.slower)
        let text = welcome ? "Welcome back. You were on step \(session.stepIndex + 1): \(session.text)" : session.text
        await speak(text, generation: generation)
        guard isCurrent(generation) else { return }
        plannerState = .idle
    }

    private func clearCoach() {
        preparedStep?.task.cancel()
        preparedStep = nil
        coach = nil
        coachStore.clear()
        conversation = []
        liveTranscript = ""
        voiceOutput.setSlower(false)
    }

    func restoreCoach() {
        guard coach == nil, isHome, let restored = coachStore.restore(guides: guides) else { return }
        coach = restored
        isHome = false
        resumeCoach()
    }

    func appEnteredBackground() {
        wasBackgrounded = true
        sessionGeneration += 1
        voiceInput.stopListening()
        stopOutput()
        plannerState = .idle
    }

    func appBecameActive() {
        guard wasBackgrounded else { return }
        wasBackgrounded = false
        if coach != nil { resumeCoach() }
    }

    private func resumeCoach() {
        sessionGeneration += 1
        if preparedStep == nil { prepareNextCoachStep() }
        let generation = sessionGeneration
        Task { await speakCoach(generation: generation, welcome: true) }
    }
}
