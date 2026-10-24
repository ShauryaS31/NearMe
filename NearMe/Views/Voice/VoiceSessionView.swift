// Adapted from a prior prototype, used with permission.

import SwiftUI

/// Read-only Home copy and action visibility, shared with presentation tests.
struct VoiceHomePresentation {
    static let idleInstruction = "Tap and tell me what you need help with"
    static let hint = "Try: 'Help me play a song on YouTube'"

    let activity: VoiceActivity
    let isHome: Bool
    let reply: String?
    let hasCompletedJourney: Bool

    var showsCancel: Bool { activity == .listening }
    var statusText: String {
        if activity == .ready { return Self.idleInstruction }
        return activity.title
    }
    var hintText: String? { activity == .ready ? Self.hint : nil }

    var showsStop: Bool { activity == .speaking }
    var showsEndSession: Bool { hasCompletedJourney && !isHome }
}

struct VoiceSessionView: View {
    @ObservedObject var engine: TaskPlannerEngine
    @State private var typedText = ""
    @State private var sheet: VoiceSessionSheet?
    @State private var isPaused = false
    @State private var isEditingReply = false
    @FocusState private var textEntryFocused: Bool

    private var state: SessionDockState {
        SessionDockState(plannerState: engine.plannerState, isSpeaking: engine.isVoiceOutputActive,
                         isStartingListening: engine.isStartingListening)
    }

    private var activity: VoiceActivity {
        VoiceActivity.resolve(plannerState: engine.plannerState, isSpeaking: engine.isVoiceOutputActive,
                              isPreparing: engine.isPreparingSpeech, isStartingListening: engine.isStartingListening,
                              isPaused: isPaused)
    }

    private var reply: String? {
        if engine.isHome { return nil }
        return CoachPresentation.reply(session: engine.coach, error: engine.lastErrorMessage)
    }

    private var showsTypedEntry: Bool { engine.isTyping && (reply == nil || isEditingReply) }

    private var presentation: VoiceHomePresentation {
        VoiceHomePresentation(activity: activity, isHome: engine.isHome, reply: reply,
                             hasCompletedJourney: engine.hasCompletedAtLeastOneJourney)
    }

    private var sendEmphasis: ButtonEmphasis {
        if reply == nil { return .primary }
        return .secondary
    }

    private var transcript: ConversationPresentation {
        let liveText: String
        switch engine.plannerState {
        case .listening, .finishing, .thinking: liveText = engine.liveTranscript
        default: liveText = ""
        }
        let turns: [ConversationTurn] = engine.isHome ? [] : engine.conversation
        let presentation = ConversationPresentation(turns: turns, liveTranscript: liveText)
        if let reply { return presentation.withReply(reply) }
        return presentation
    }

    var body: some View {
        NavigationStack {
            VoiceHomeContent(state: state, presentation: presentation, transcript: transcript,
                             onTalk: talk, onCancel: cancel, onType: type) {
                if showsTypedEntry { typedEntry }
                if engine.isShowingPlaceSuggestions { PlaceSuggestionsView(engine: engine) }
                if presentation.showsStop {
                    PrimaryButton(title: "Stop", systemImage: "stop.fill", emphasis: .secondary) {
                        engine.stopSessionSpeech()
                        isPaused = true
                    }
                }
            }
            .navigationTitle("NearMe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TTColor.paleLavender, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    VoiceSessionMenu(showsEndSession: presentation.showsEndSession, onSelect: select)
                }
            }
        }
        .tint(TTColor.accent)
        .sheet(item: $sheet) { destination in
            switch destination {
            case .screen: ScreenBroadcastPickerSheet()
            case .settings: VoiceSettingsSheet()
            }
        }
        .onChange(of: engine.isTyping) { _, typing in textEntryFocused = typing }
        .onChange(of: engine.plannerState) { _, newState in
            if newState != .idle { isPaused = false }
        }
        .onAppear { textEntryFocused = engine.isTyping }
    }

    private var typedEntry: some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            TextField("Type your answer", text: $typedText)
                .font(TTFont.body())
                .textFieldStyle(.roundedBorder)
                .focused($textEntryFocused)
                .accessibilityLabel("Your answer")
                .submitLabel(.send)
                .onSubmit(send)
            PrimaryButton(title: "Send", systemImage: "paperplane.fill",
                          emphasis: sendEmphasis, action: send)
                .disabled(!canSend)
        }
    }

    private var canSend: Bool {
        TypedAnswerPresentation.canSend(typedText, canSubmit: engine.canSubmitTypedInput,
                                       isAwaitingSong: engine.isAwaitingSong)
    }

    private func select(_ action: VoiceMenuAction) {
        switch action {
        case .screen:
            textEntryFocused = false
            sheet = .screen
        case .practice: engine.startPractice()
        case .type: type()
        case .settings:
            textEntryFocused = false
            sheet = .settings
        case .endSession: engine.endSession()
        #if DEBUG
        case .debug: engine.showsDebugInfo.toggle()
        #endif
        }
    }

    private func send() {
        guard canSend else { return }
        isPaused = false
        isEditingReply = false
        engine.submitTypedInput(typedText)
        typedText = ""
        textEntryFocused = false
    }

    private func talk() {
        // A non-step session must be cleared so a new request is not parsed as a coach command.
        if let coach = engine.coach, CoachPresentation.kind(for: coach) == .homeReply {
            engine.cancelCurrentAction()
        }
        isPaused = false
        textEntryFocused = false
        engine.userTappedToTalk()
    }

    private func type() {
        if let coach = engine.coach, CoachPresentation.kind(for: coach) == .homeReply {
            engine.cancelCurrentAction()
        }
        isPaused = false
        isEditingReply = true
        engine.useTypedInput()
        textEntryFocused = true
    }

    private func cancel() {
        engine.cancelCurrentAction()
        typedText = ""
        isEditingReply = false
        isPaused = false
        textEntryFocused = false
    }
}

struct PlaceSuggestionsView: View {
    @ObservedObject var engine: TaskPlannerEngine

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            Text("I heard: \(engine.suggestionTranscript)").font(TTFont.body())
            Text(engine.suggestionQuestion).font(TTFont.title())
            ForEach(engine.placeSuggestions, id: \.self) { place in
                PrimaryButton(title: place, systemImage: "mappin.circle", emphasis: .secondary) {
                    engine.chooseSuggestedPlace(place)
                }
            }
            PrimaryButton(title: "Keep what I said", systemImage: "checkmark", emphasis: .secondary,
                          action: engine.keepSuggestedPlace)
            PrimaryButton(title: "Say it again", systemImage: "mic.fill", emphasis: .secondary,
                          action: engine.retrySuggestedPlace)
        }
    }

}

/// Read-only grouping; it never changes the engine's conversation or speech state.
struct ConversationPresentation {
    let userText: String?
    private(set) var replyText: String?
    private(set) var earlier: [ConversationTurn]
    private let currentReply: ConversationTurn?

    var hasContent: Bool { userText != nil || replyText != nil || !earlier.isEmpty }

    init(turns: [ConversationTurn], liveTranscript: String) {
        let lastUserIndex: Int? = turns.lastIndex { $0.speaker == .user }
        let startIndex: Int = lastUserIndex ?? max(0, turns.count - 1)
        let current: [ConversationTurn] = Array(turns.dropFirst(startIndex))
        let lastReply: ConversationTurn? = current.last { $0.speaker == .nearme }
        let lastUser: ConversationTurn? = current.last { $0.speaker == .user }
        currentReply = liveTranscript.isEmpty ? lastReply : nil
        if liveTranscript.isEmpty {
            userText = lastUser?.text
            replyText = lastReply?.text
            // Keep every older reply, even when several prompts follow one user turn.
            let currentIDs = Set([lastUser?.id, lastReply?.id].compactMap { $0 })
            earlier = turns.filter { !currentIDs.contains($0.id) }
        } else {
            userText = liveTranscript
            replyText = nil
            // Recognised final text can already have been appended while thinking.
            if lastUser?.text == liveTranscript, let lastUser {
                earlier = turns.filter { $0.id != lastUser.id }
            } else {
                earlier = turns
            }
        }
    }

    func withReply(_ text: String) -> Self {
        var presentation = self
        if let currentReply, currentReply.text != text {
            presentation.earlier.append(currentReply)
        }
        presentation.replyText = text
        return presentation
    }
}

struct ConversationTranscript: View {
    let presentation: ConversationPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
            if let userText = presentation.userText {
                turn(label: "You said", text: userText, isCurrentReply: false)
            }
            if let replyText = presentation.replyText {
                turn(label: "NearMe", text: replyText, isCurrentReply: true)
            }
            if !presentation.earlier.isEmpty {
                DisclosureGroup("Earlier conversation") {
                    VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
                        ForEach(presentation.earlier) { entry in
                            turn(label: entry.speaker == .user ? "You said" : "NearMe",
                                 text: entry.text, isCurrentReply: false)
                        }
                    }
                    .padding(.top, TTSpacing.relatedGap)
                }
                .font(TTFont.body())
            }
        }
        .padding(TTSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TTColor.readingSurface,
                    in: RoundedRectangle(cornerRadius: TTRadius.card, style: .continuous))
    }

    private func turn(label: String, text: String, isCurrentReply: Bool) -> some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            Text(label).font(TTFont.body()).foregroundStyle(TTColor.textSecondary)
            Text(text)
                .font(isCurrentReply ? TTFont.title() : TTFont.body())
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
