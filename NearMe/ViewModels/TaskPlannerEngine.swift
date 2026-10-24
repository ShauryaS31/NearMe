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
    // Last user-turn understanding; never overwritten by reply generation.
    @Published private(set) var latestBrainSource: BrainSource
    @Published private(set) var latestBrainFallbackReason: ModelFallbackReason?
    @Published private(set) var latestReplySource: BrainSource = .template
    @Published private(set) var latestBrainLatencyMilliseconds: Int?
    @Published private(set) var isTyping = false
    @Published private(set) var latestVoice: String?
    @Published private(set) var isVoiceOutputActive = false
    @Published private(set) var isStartingListening = false
    @Published private(set) var coach: CoachSession?
    @Published private(set) var isHome = true
    #if DEBUG
    @Published var showsDebugInfo = false
    #endif
    private let guides: [HelpGuide]
    private let helpRouter: any HelpRouting
    private let coachService: CoachModelService
    private let coachStore: CoachProgressStore
    private let activityUpdater: any CoachActivityUpdating
    private var progressObservation: AnyCancellable?
    private var finishingCoachID: UUID?
    private let appOpener: any CoachAppOpening
    private var pendingAppOpen: UUID?
    private var resumeAfterAppOpen = false
    private var tripRouteActive = false
    private var coachReplySource: BrainSource = .template
    private var preparedStep: (index: Int, task: Task<BrainAnswer<String>, Never>)?
    private var wasBackgrounded = false
    private var isSceneActive = false
    private var playbackGeneration = 0
    private var acknowledgement: Task<Void, Never>?
    private var acknowledgementGeneration: Int?
    private static let acknowledgementLine = "Sure, let me help you with that."
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

    var debugBadge: SessionDebugBadge {
        SessionDebugBadge(understanding: latestBrainSource, modelMilliseconds: latestBrainLatencyMilliseconds,
                          reply: latestReplySource, voice: latestVoice,
                          firstAudioMilliseconds: firstAudioMilliseconds, sttMilliseconds: sttMilliseconds,
                          fallbackReason: latestBrainFallbackReason)
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
         guides: [HelpGuide]? = nil, helpRouter: (any HelpRouting)? = nil,
         coachService: CoachModelService? = nil, coachStore: CoachProgressStore? = nil,
         appOpener: (any CoachAppOpening)? = nil,
         activityUpdater: (any CoachActivityUpdating)? = nil) {
        let library = guides ?? GuideLibrary.bundled()
        let service = coachService ?? CoachModelService.makeDefault()
        self.guides = library
        self.coachService = service
        self.helpRouter = helpRouter ?? HelpRouter(guides: library, service: service)
        self.coachStore = coachStore ?? CoachProgressStore()
        self.activityUpdater = activityUpdater ?? CoachActivityUpdater.shared
        self.appOpener = appOpener ?? SystemCoachAppOpener()
        self.brain = brain
        self.latestBrainSource = .template
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
            // Capture is already stopped at speech end; allow its final decoded result
            // while the acknowledgement plays, without accepting live microphone audio.
            let finalizing = self.plannerState == .finishing && !self.voiceInput.isListening && self.speechEndedAt != nil
            return (!self.isVoiceOutputActive || finalizing) && !self.isStartingListening
        }
        self.voiceOutput.onVoiceChanged = { [weak self] voice in self?.latestVoice = voice }
        self.voiceOutput.onPlaybackStarted = { [weak self] in self?.recordFirstAudio() }
        progressObservation = NotificationCenter.default.publisher(for: CoachProgressStore.didChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.synchronizeSavedCoach() }
            }
        self.voiceOutput.prefetch(Self.acknowledgementLine)
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
        liveTranscript = ""
        if let practice = tripPlannerPracticeViewModel {
            plannerState = .guiding(practice.step)
        } else {
            plannerState = .idle
        }
        // Keep pendingClarification and its retry count when changing input mode.
    }

    var canSubmitTypedInput: Bool {
        guard isTyping, !isVoiceOutputActive, !isStartingListening else { return false }
        if plannerState == .idle { return true }
        if case .guiding = plannerState { return true }
        return false
    }

    func performDockAction(_ action: SessionDockAction) {
        switch action {
        case .repeatStep:
            if coach != nil { coachCommand(.repeatStep) }
            else { repeatPracticeCaption() }
        case .slower:
            if coach != nil { coachCommand(.slower) }
            else { repeatPracticeCaption(slower: true) }
        case .typeInstead: useTypedInput()
        case .endSession: endSession()
        }
    }

    /// Silence immediately, retaining the current practice or coach step.
    func stopSessionSpeech() {
        if tripPlannerPracticeViewModel != nil {
            stopPracticeSpeech()
            return
        }
        sessionGeneration += 1
        voiceInput.stopListening()
        stopOutput()
        isPreparingSpeech = false
        plannerState = .idle
    }

    func submitTypedInput(_ text: String) {
        let transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSubmitTypedInput, !transcript.isEmpty else { return }
        sessionGeneration += 1
        let generation = sessionGeneration
        lastErrorMessage = nil
        clearSuggestions()
        clearTurn()
        spokenInput = false
        speechEndedAt = ProcessInfo.processInfo.systemUptime
        plannerState = .thinking
        beginAcknowledgement(for: transcript, generation: generation)
        Task { await receive(transcript: transcript, generation: generation) }
    }

    /// "cancel" — stops whatever NearMe is currently doing and returns to a
    /// neutral, tappable idle state rather than silently continuing.
    func cancelCurrentAction() {
        resetDebugInfo()
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
        returnHome(clearingProgress: true)
    }

    private func returnHome(clearingProgress: Bool) {
        resetDebugInfo()
        lastErrorMessage = nil
        clearCoach(clearProgress: clearingProgress)
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
    private func speak(_ text: String, generation: Int, updatesPlannerState: Bool = true,
                       greeting: Bool = false, acknowledgement: Bool = false, replySource: BrainSource? = nil) async {
        guard isCurrent(generation) else { return }
        latestReplySource = replySource ?? .template
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
        if acknowledgement { await voiceOutput.speakAcknowledgement(text) }
        else if greeting { await voiceOutput.speakGreeting(text) }
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
            self.speechEndedAt = self.voiceInput.lastTurn.endedAt ?? ProcessInfo.processInfo.systemUptime
            self.plannerState = .finishing
            self.beginAcknowledgement(for: transcript, generation: generation)
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
            if acknowledgementGeneration == generation { stopOutput() }
            consecutiveInputFailures = 0
            lastErrorMessage = VoiceDiagnostics.message(for: VoiceInputError.noSpeechDetected)
            await speak(VoiceDiagnostics.message(for: VoiceInputError.noSpeechDetected), generation: generation)
            guard isCurrent(generation) else { return }
            plannerState = .idle
        } catch {
            VoiceDiagnostics.log(error)
            guard isCurrent(generation) else { return }
            if acknowledgementGeneration == generation { stopOutput() }
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
            latestBrainSource = .keywordFallback
            latestBrainFallbackReason = nil
            latestBrainLatencyMilliseconds = nil
            await handleCoachCommand(CoachCommand.parse(transcript), generation: generation)
            return
        }
        if tripPlannerPracticeViewModel != nil {
            latestBrainSource = .keywordFallback
            latestBrainFallbackReason = nil
            latestBrainLatencyMilliseconds = nil
            latestReplySource = .template
            let command = transcript.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
            switch command {
            case "stop", "end": cancelCurrentAction()
            case "slower": repeatPracticeCaption(slower: true)
            default: repeatPracticeCaption()
            }
            return
        }
        if !tripRouteActive {
            if let command = CoachCommand.parse(transcript) {
                if command == .stop { cancelCurrentAction() }
                else { plannerState = .idle }
                return
            }
            beginAcknowledgement(for: transcript, generation: generation)
            let answer = await helpRouter.route(transcript)
            if acknowledgementGeneration == generation { await acknowledgement?.value }
            guard isCurrent(generation) else { return }
            latestBrainSource = answer.source
            latestBrainFallbackReason = answer.fallbackReason
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
                latestBrainFallbackReason = answer.fallbackReason
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
                        pendingClarification = .destination
                        clarificationFailures = 0
                        currentIntent = .empty
                        currentIntent.intent = .planJourney
                        tripRouteActive = true
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
            latestBrainFallbackReason = answer.fallbackReason
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
            latestReplySource = .template
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
        latestReplySource = .template
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
        acknowledgement?.cancel()
        acknowledgement = nil
        acknowledgementGeneration = nil
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
        latestReplySource = .template
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
        acknowledgement = nil
        acknowledgementGeneration = nil
        speechEndedAt = nil
        sttMilliseconds = nil
        firstAudioMilliseconds = nil
        latestBrainLatencyMilliseconds = nil
        latestBrainFallbackReason = nil
        latestReplySource = .template
    }

    private func elapsedSinceSpeechEnd() -> Int? {
        speechEndedAt.map { max(0, Int((ProcessInfo.processInfo.systemUptime - $0) * 1000)) }
    }

    private func recordFirstAudio() {
        guard firstAudioMilliseconds == nil, let elapsed = elapsedSinceSpeechEnd() else { return }
        firstAudioMilliseconds = elapsed
        VoiceDiagnostics.logger.info("First audio ms=\(elapsed)")
    }

    private func beginAcknowledgement(for transcript: String, generation: Int) {
        guard isCurrent(generation), acknowledgementGeneration != generation,
              coach == nil, !tripRouteActive, tripPlannerPracticeViewModel == nil,
              pendingClarification == nil, suggestionSlot == nil,
              !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              CoachCommand.parse(transcript) == nil else { return }
        acknowledgementGeneration = generation
        acknowledgement = Task { [weak self] in
            guard let self, self.isCurrent(generation), !Task.isCancelled else { return }
            self.voiceOutput.setSlower(false)
            await self.speak(Self.acknowledgementLine, generation: generation,
                             updatesPlannerState: false, acknowledgement: true)
        }
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
        if !slower { practice.repeatHighlight() }
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

    // MARK: - Guided and general coach

    func startPractice() {
        cancelCurrentAction()
        isHome = false
        // The card explicitly selects practiceTripPlanner; no router/model call is needed.
        tripRouteActive = true
        // No user turn has been understood in this practice session yet.
        latestBrainSource = .template
        latestBrainFallbackReason = nil
        latestBrainLatencyMilliseconds = nil
        latestReplySource = .template
        latestVoice = nil
        currentIntent.intent = .planJourney
        let generation = sessionGeneration
        Task { await proceedAfterIntentUpdate(generation: generation) }
    }

    private func startCoach(guide: HelpGuide, request: String, person: String?, generation: Int) async {
        let person = PersonNormalization.extract(from: request) ?? PersonNormalization.normalize(person)
        voiceOutput.setSlower(false)
        coach = CoachSession(guide: guide, request: request, person: PersonNormalization.normalize(person),
                             generalSteps: [], stepIndex: 0, text: CoachText.fallback(step: guide.steps[0], person: person))
        persistCoach(startIfNeeded: true)
        if await autoOpenCoachApp(generation: generation) { return }
        await presentCoachStep(generation: generation)
    }

    /// The spoken announcement must finish before handing off to another app.
    private func autoOpenCoachApp(generation: Int) async -> Bool {
        guard let session = coach, let guide = session.guide else { return false }
        guard session.stepIndex == 0 else {
            PlannerDiagnostics.logger.notice("Auto-open guide=\(guide.id, privacy: .public) skipped=not first step")
            return false
        }
        guard let url = CoachAppLaunch.url(for: guide) else {
            PlannerDiagnostics.logger.notice("Auto-open guide=\(guide.id, privacy: .public) skipped=no scheme or opening step")
            return false
        }
        let canOpen = appOpener.canOpen(url)
        PlannerDiagnostics.logger.notice("Auto-open guide=\(guide.id, privacy: .public) url=\(url.absoluteString, privacy: .public) canOpenURL=\(canOpen, privacy: .public)")
        guard canOpen else {
            PlannerDiagnostics.logger.notice("Auto-open guide=\(guide.id, privacy: .public) skipped=not installed")
            await speak("\(guide.app) isn't on this phone.", generation: generation)
            return false
        }
        let announcement = "I'll open \(guide.app) for you now."
        coach?.text = announcement
        await speak(announcement, generation: generation)
        guard isCurrent(generation), coach?.id == session.id else {
            PlannerDiagnostics.logger.notice("Auto-open guide=\(guide.id, privacy: .public) skipped=interrupted")
            // Stop or a mode change cancels the handoff and restores the normal step.
            if coach?.id == session.id, coach?.stepIndex == 0, coach?.text == announcement {
                coach?.text = session.text
            }
            return true
        }

        // Persist before open can background the app. A failed open rolls this back.
        coach?.stepIndex = 1
        coach?.revision += 1
        coach?.text = CoachText.fallback(step: guide.steps[1], person: session.person)
        persistCoach()
        plannerState = .idle
        // Publish step 2 before handing off, while the app is still foregrounded.
        await activityUpdater.flush()
        synchronizeSavedCoach()
        guard coach?.id == session.id, coach?.stepIndex == 1,
              coach?.revision == session.revision + 1, isCurrent(generation) else {
            // Cancellation before the handoff must not leave a skipped opening step.
            if coach?.id == session.id, coach?.revision == session.revision + 1 {
                coach?.stepIndex = 0
                coach?.revision += 1
                coach?.text = session.text
                persistCoach()
            }
            return true
        }
        pendingAppOpen = session.id
        let opened = await appOpener.open(url)
        PlannerDiagnostics.logger.notice("Auto-open guide=\(guide.id, privacy: .public) url=\(url.absoluteString, privacy: .public) opened=\(opened, privacy: .public)")
        synchronizeSavedCoach()
        guard pendingAppOpen == session.id, coach?.id == session.id else { return true }
        pendingAppOpen = nil
        let shouldResume = resumeAfterAppOpen
        resumeAfterAppOpen = false
        // Do not overwrite a step the user advanced while the system was opening.
        if !opened, coach?.stepIndex == 1 {
            coach?.stepIndex = 0
            coach?.revision += 1
            coach?.text = session.text
            persistCoach()
        }
        guard !wasBackgrounded else { return true }
        if shouldResume {
            resumeCoach()
        } else if isCurrent(generation) {
            await presentCoachStep(generation: generation)
        }
        return true
    }

    private func startGeneral(request: String, generation: Int) async {
        let answer = await coachService.general(request: request)
        guard isCurrent(generation) else { return }
        coachReplySource = answer.source == .keywordFallback ? .template : answer.source
        voiceOutput.setSlower(false)
        if let coach, coach.guide != nil {
            activityUpdater.enqueue(.stop(coach.id))
        }
        coachStore.clear()
        coach = CoachSession(guide: nil, request: request, person: nil, generalSteps: answer.value,
                             stepIndex: 0, text: answer.value.first ?? CoachText.generalFallback)
        await presentCoachStep(generation: generation)
    }

    func coachCommand(_ command: CoachCommand) {
        guard let displayedSession = coach else { return }
        synchronizeSavedCoach()
        guard let currentSession = coach else { return }
        // A tap on the old card must not consume the revision an intent just saved.
        if command == .next,
           displayedSession.id != currentSession.id || displayedSession.revision != currentSession.revision {
            return
        }
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
            if session.guide != nil {
                let saved = coachStore.load()
                guard saved?.sessionID == session.id, saved?.revision == session.revision else {
                    synchronizeSavedCoach()
                    return
                }
            }
            if session.stepIndex + 1 == session.count {
                preparedStep?.task.cancel()
                preparedStep = nil
                coach?.text = "That's it, you're done."
                coachReplySource = .template
                finishingCoachID = session.id
                if let guide = session.guide {
                    let progress = CoachProgress(guideID: guide.id, stepIndex: session.stepIndex,
                                                 sessionID: session.id, revision: session.revision + 1)
                    if let snapshot = CoachActivitySnapshot.build(progress: progress, guide: guide.activityGuide, completed: true) {
                        activityUpdater.enqueue(.finish(snapshot))
                    }
                }
                coachStore.clear()
                await speak("That's it, you're done.", generation: generation)
                // Completion is persisted even if speech is interrupted by backgrounding.
                guard coach?.id == session.id else { return }
                // Progress is already cleared. Keep the final activity visible for 30 seconds.
                returnHome(clearingProgress: false)
            } else {
                coach?.stepIndex += 1
                coach?.revision += 1
                persistCoach()
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
                coachReplySource = answer.source == .keywordFallback ? .template : answer.source
            } else {
                plannerState = .thinking
                let answer = await coachService.generalStuck(step: session.generalSteps[session.stepIndex])
                guard isCurrent(generation), coach?.id == session.id else { return }
                coach?.text = answer.value
                coachReplySource = answer.source == .keywordFallback ? .template : answer.source
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
            coachReplySource = answer.source == .keywordFallback ? .template : answer.source
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
        await speak(text, generation: generation, replySource: coachReplySource)
        guard isCurrent(generation) else { return }
        plannerState = .idle
    }

    private func clearCoach(clearProgress: Bool = true) {
        if clearProgress {
            if let coach, coach.guide != nil {
                activityUpdater.enqueue(.stop(coach.id))
            }
            coachStore.clear()
        }
        finishingCoachID = nil
        pendingAppOpen = nil
        resumeAfterAppOpen = false
        preparedStep?.task.cancel()
        preparedStep = nil
        coach = nil
        coachReplySource = .template
        conversation = []
        liveTranscript = ""
        voiceOutput.setSlower(false)
    }

    func restoreCoach() {
        guard isSceneActive, coach == nil, isHome,
              let restored = coachStore.restore(guides: guides) else { return }
        coach = restored
        isHome = false
        publishCoach(startIfNeeded: true)
        resumeCoach()
    }

    private func persistCoach(startIfNeeded: Bool = true) {
        guard let coach else { return }
        coachStore.save(coach)
        publishCoach(startIfNeeded: startIfNeeded)
    }

    private func publishCoach(startIfNeeded: Bool) {
        guard let coach, let guide = coach.guide else { return }
        let progress = CoachProgress(guideID: guide.id, stepIndex: coach.stepIndex,
                                     sessionID: coach.id, revision: coach.revision)
        if let snapshot = CoachActivitySnapshot.build(progress: progress, guide: guide.activityGuide) {
            activityUpdater.enqueue(.show(snapshot, startIfNeeded: startIfNeeded))
        }
    }

    /// An intent may run with this engine suspended, or before any engine exists.
    /// Observing the store updates the card without speaking/recording in the background.
    private func synchronizeSavedCoach() {
        guard let session = coach, session.guide != nil, finishingCoachID != session.id else { return }
        guard let progress = coachStore.load(), progress.sessionID == session.id,
              let guide = session.guide, guide.id == progress.guideID,
              guide.steps.indices.contains(progress.stepIndex) else {
            returnHome(clearingProgress: false)
            return
        }
        guard progress.revision != session.revision || progress.stepIndex != session.stepIndex else { return }
        sessionGeneration += 1
        voiceInput.stopListening()
        stopOutput()
        preparedStep?.task.cancel()
        preparedStep = nil
        pendingAppOpen = nil
        resumeAfterAppOpen = false
        coach?.stepIndex = progress.stepIndex
        coach?.revision = progress.revision
        coach?.text = CoachText.fallback(step: guide.steps[progress.stepIndex], person: session.person)
        coachReplySource = .template
        isPreparingSpeech = false
        plannerState = .idle
    }

    func openCoachURL(_ url: URL) {
        guard isSceneActive else { return }
        guard CoachDeepLink.parse(url, savedSessionID: nil) != .ignored else { return }
        let restored = coachStore.restore(guides: guides)
        switch CoachDeepLink.parse(url, savedSessionID: restored?.id) {
        case .ignored: return
        case .home:
            returnHome(clearingProgress: false)
        case .coach(let sessionID):
            if coach?.id == sessionID {
                synchronizeSavedCoach()
                isHome = false
                return
            }
            returnHome(clearingProgress: false)
            coach = restored
            isHome = false
            publishCoach(startIfNeeded: true)
            resumeCoach()
        }
    }

    func appEnteredBackground() {
        isSceneActive = false
        wasBackgrounded = true
        sessionGeneration += 1
        voiceInput.stopListening()
        stopOutput()
        isPreparingSpeech = false
        if let practice = tripPlannerPracticeViewModel {
            plannerState = .guiding(practice.step)
        } else {
            plannerState = .idle
        }
    }

    func appBecameActive() {
        isSceneActive = true
        synchronizeSavedCoach()
        guard wasBackgrounded else { return }
        wasBackgrounded = false
        if pendingAppOpen != nil {
            resumeAfterAppOpen = true
            return
        }
        if coach != nil { resumeCoach() }
    }

    private func resumeCoach() {
        guard isSceneActive else { return }
        if let session = coach, let guide = session.guide {
            PlannerDiagnostics.logger.notice("Auto-open guide=\(guide.id, privacy: .public) skipped=resuming existing session step=\(session.stepIndex + 1, privacy: .public)")
        }
        sessionGeneration += 1
        if preparedStep == nil { prepareNextCoachStep() }
        let generation = sessionGeneration
        Task {
            guard self.isSceneActive else { return }
            await speakCoach(generation: generation, welcome: true)
        }
    }

    func appBecameInactive() {
        isSceneActive = false
    }

    private func resetDebugInfo() {
        #if DEBUG
        showsDebugInfo = false
        #endif
    }
}
