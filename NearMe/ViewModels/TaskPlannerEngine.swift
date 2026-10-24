// Adapted from a prior prototype, used with permission.

import Foundation
import Combine
import OSLog

@MainActor
final class TaskPlannerEngine: ObservableObject {
    @Published private(set) var plannerState: TaskPlannerState = .idle
    @Published private(set) var conversation: [ConversationTurn] = []
    @Published private(set) var ptvSimulationViewModel: PTVSimulationViewModel?
    @Published private(set) var currentIntent: JourneyIntent = .empty
    @Published var liveTranscript: String = ""
    @Published var lastErrorMessage: String?
    @Published private(set) var hasCompletedAtLeastOneJourney = false
    @Published private(set) var latestBrainSource: BrainSource
    @Published private(set) var latestBrainLatencyMilliseconds: Int?
    @Published private(set) var isTyping = false

    private let brain: TaskPlannerBrain
    private let voiceInput: VoiceInputService
    private let voiceOutput: VoiceOutputService
    private let permissions: PermissionsManager
    private let userName: String

    private var pendingClarification: MissingSlot?
    private var clarificationFailures = 0
    /// Guards against overlapping listen/speak loops if the user mashes buttons.
    private var sessionGeneration = 0

    init(brain: TaskPlannerBrain,
         voiceInput: VoiceInputService,
         voiceOutput: VoiceOutputService,
         permissions: PermissionsManager,
         userName: String) {
        self.brain = brain
        self.latestBrainSource = brain.initialSource
        self.voiceInput = voiceInput
        self.voiceOutput = voiceOutput
        self.permissions = permissions
        self.userName = userName
    }

    // MARK: - Entry points

    func beginSession() {
        sessionGeneration += 1
        let generation = sessionGeneration
        Task { await runGreeting(generation: generation) }
    }

    /// User tapped the orb from an idle state to speak again.
    func userTappedToTalk() {
        sessionGeneration += 1
        isTyping = false
        lastErrorMessage = nil
        let generation = sessionGeneration
        Task {
            guard await ensurePermissions(generation: generation), isCurrent(generation) else { return }
            await listenAndHandle(generation: generation)
        }
    }

    func useTypedInput() {
        sessionGeneration += 1
        voiceInput.stopListening()
        voiceOutput.stop()
        isTyping = true
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
        plannerState = .thinking
        Task { await receive(transcript: transcript, generation: generation) }
    }

    /// "cancel" — stops whatever NearMe is currently doing and returns to a
    /// neutral, tappable idle state rather than silently continuing.
    func cancelCurrentAction() {
        sessionGeneration += 1
        isTyping = false
        voiceInput.stopListening()
        voiceOutput.stop()
        pendingClarification = nil
        clarificationFailures = 0
        currentIntent = .empty
        ptvSimulationViewModel = nil
        plannerState = .idle
    }

    /// "end session" — stops everything for good. There's no separate "ended"
    /// screen in the mockups; the caller (SessionContainerView) navigates
    /// straight back to onboarding once this returns.
    func endSession() {
        sessionGeneration += 1
        isTyping = false
        voiceInput.stopListening()
        voiceOutput.stop()
        ptvSimulationViewModel = nil
        plannerState = .idle
    }

    // MARK: - Greeting

    private func runGreeting(generation: Int) async {
        guard await ensurePermissions(generation: generation) else { return }
        guard isCurrent(generation) else { return }
        await speak("Hi, what can we help you with?", generation: generation)
        guard isCurrent(generation) else { return }
        await listenAndHandle(generation: generation)
    }

    private func ensurePermissions(generation: Int) async -> Bool {
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
            // FIX: the system's microphone/speech-recognition permission
            // alerts briefly disrupt the audio hardware layer. Activating
            // our own AVAudioSession (the greeting's TTS, right after this
            // returns) the instant those dialogs dismiss can race the OS
            // still settling from presenting them, producing
            // kAudioUnitErr_CannotDoInCurrentContext ("IPCAUClient: can't
            // connect to server") on that very first activation. Only
            // needed the one time permissions are actually being granted —
            // once already authorized on a later session, skip the wait.
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return true
    }

    // MARK: - Core loop

    /// FIX: `updatesPlannerState` defaults to `true` for the plain voice loop
    /// (idle/listening/thinking screens, which rely on `.speaking(text)` to
    /// show the right orb state and subtitle). The two guided-walkthrough
    /// call sites below pass `false`: they set `plannerState = .guiding(step)`
    /// immediately before calling this, and `PTVSimulationView` already shows
    /// its own caption via `viewModel.currentCaption` — so if this function
    /// were allowed to overwrite `plannerState` to `.speaking(text)` here, it
    /// would immediately un-set `.guiding`, and `SessionContainerView` would
    /// switch straight back to the plain voice screen before the simulated
    /// PTV screen was ever actually visible. That was the root cause of the
    /// guided walkthrough never visibly appearing.
    private func speak(_ text: String, generation: Int, updatesPlannerState: Bool = true) async {
        guard isCurrent(generation) else { return }
        if updatesPlannerState {
            plannerState = .speaking(text)
        }
        conversation.append(ConversationTurn(speaker: .nearme, text: text))
        await voiceOutput.speak(text)
    }

    private func listenAndHandle(generation: Int) async {
        guard isCurrent(generation) else { return }
        if isTyping {
            plannerState = .idle
            return
        }
        lastErrorMessage = nil
        plannerState = .listening
        liveTranscript = ""

        do {
            let transcript = try await voiceInput.startListening { [weak self] partial in
                guard let self, self.isCurrent(generation) else { return }
                self.liveTranscript = partial
            }
            guard isCurrent(generation) else { return }
            await receive(transcript: transcript, generation: generation)
        } catch VoiceInputError.noSpeechDetected {
            VoiceDiagnostics.log(VoiceInputError.noSpeechDetected)
            guard isCurrent(generation) else { return }
            lastErrorMessage = VoiceDiagnostics.message(for: VoiceInputError.noSpeechDetected)
            await speak("Sorry, I didn't catch that — what do you need help with?", generation: generation)
            guard isCurrent(generation) else { return }
            await listenAndHandle(generation: generation)
        } catch {
            VoiceDiagnostics.log(error)
            guard isCurrent(generation) else { return }
            lastErrorMessage = VoiceDiagnostics.message(for: error)
            plannerState = .idle
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
                await speak("I can help you plan a PTV journey — try telling me where you'd like to go, like \"I need to get to Melbourne Central.\"", generation: generation)
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

        if let missing = currentIntent.firstMissingSlot {
            pendingClarification = missing
            clarificationFailures = 0
            let answer: BrainAnswer<String>
            do {
                answer = try await brain.clarifyingQuestion(for: missing, currentIntent: currentIntent)
            } catch {
                PlannerDiagnostics.fallback(after: error, call: "clarifyingQuestion")
                answer = BrainAnswer(value: missing == .origin ? "Sure! Where are you leaving from?" : "And where are you headed?", source: .keywordFallback)
            }
            guard isCurrent(generation) else { return }
            latestBrainSource = answer.source
            latestBrainLatencyMilliseconds = answer.latencyMilliseconds
            await speak(answer.value, generation: generation)
            guard isCurrent(generation) else { return }
            await listenAndHandle(generation: generation)
        } else {
            await openPTVAndGuide(generation: generation)
        }
    }

    // MARK: - Opening PTV + guided walkthrough

    private func openPTVAndGuide(generation: Int) async {
        guard isCurrent(generation) else { return }
        let answer: BrainAnswer<String>
        do {
            answer = try await brain.confirmationLine(for: currentIntent)
        } catch {
            PlannerDiagnostics.fallback(after: error, call: "confirmationLine")
            answer = BrainAnswer(value: "Great! I'll help you plan that journey.", source: .keywordFallback)
        }
        guard isCurrent(generation) else { return }
        latestBrainSource = answer.source
        latestBrainLatencyMilliseconds = answer.latencyMilliseconds
        await speak(answer.value, generation: generation)
        guard isCurrent(generation) else { return }

        plannerState = .openingApp
        // v1: brief pause, then hand over to the simulated PTV walkthrough.
        // Phase 2 would call `await PTVLauncher.openJourneyPlanner()` here
        // and drive `ReplayKitVisionGuidanceService` instead of
        // `PTVSimulationViewModel`. See that file for what's involved.
        try? await Task.sleep(nanoseconds: 900_000_000)
        guard isCurrent(generation) else { return }

        let simulation = PTVSimulationViewModel(intent: currentIntent)
        simulation.onStepAdvanced = { [weak self] step in
            guard let self else { return }
            Task { await self.handleGuidanceAdvanced(step, generation: generation) }
        }
        ptvSimulationViewModel = simulation
        plannerState = .guiding(.forYouOpened)
        await speak(PTVSimStep.forYouOpened.caption(origin: currentIntent.origin ?? "", destination: currentIntent.destination ?? ""), generation: generation, updatesPlannerState: false)
    }

    private func handleGuidanceAdvanced(_ step: PTVSimStep, generation: Int) async {
        guard isCurrent(generation) else { return }
        plannerState = .guiding(step)
        let caption = step.caption(origin: currentIntent.origin ?? "", destination: currentIntent.destination ?? "")
        await speak(caption, generation: generation, updatesPlannerState: false)
        guard isCurrent(generation) else { return }

        if step == .showingResults {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard isCurrent(generation) else { return }
            ptvSimulationViewModel = nil
            currentIntent = .empty
            hasCompletedAtLeastOneJourney = true
            await listenAndHandle(generation: generation)
        }
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == sessionGeneration
    }
}
