// Adapted from a prior prototype, used with permission.

import SwiftUI

/// Read-only Home copy and action visibility, shared with presentation tests.
struct HelpHomePresentation {
    static let hint = "Try: 'Help me send a photo to Mum on WhatsApp'"

    let activity: VoiceActivity
    let isHome: Bool
    let reply: String?
    let hasCompletedJourney: Bool

    var showsCancel: Bool {
        if activity == .listening || activity == .preparing { return true }
        return !isHome && reply == nil
    }

    var showsStop: Bool { activity == .speaking }
    var showsEndSession: Bool { hasCompletedJourney && !isHome }
}

struct HelpHomeView: View {
    @ObservedObject var engine: TaskPlannerEngine
    @State private var typedText = ""
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

    private var presentation: HelpHomePresentation {
        HelpHomePresentation(activity: activity, isHome: engine.isHome, reply: reply,
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
            HelpHomeContent(state: state, activity: activity, transcript: transcript,
                            showsRetry: reply != nil, isTyping: showsTypedEntry,
                            showsCancel: presentation.showsCancel,
                            onTalk: talk, onCancel: cancel,
                            onType: type, onPractice: engine.startPractice) {
                if showsTypedEntry { typedEntry }
                if engine.isShowingPlaceSuggestions { PlaceSuggestionsView(engine: engine) }
                if presentation.showsStop {
                    PrimaryButton(title: "Stop", systemImage: "stop.fill", emphasis: .secondary) {
                        engine.stopSessionSpeech()
                        isPaused = true
                    }
                }
                if presentation.showsEndSession {
                    PrimaryButton(title: "End session", systemImage: "xmark.circle", emphasis: .secondary,
                                  action: engine.endSession)
                }
            }
            .navigationTitle("NearMe")
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SessionDebugMenu(engine: engine) }
            }
            #endif
        }
        .tint(TTColor.accent)
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
        engine.canSubmitTypedInput && !typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

/// Home remains the same view during capture, preparation and a non-step reply.
struct HelpHomeContent<Actions: View>: View {
    let state: SessionDockState
    let activity: VoiceActivity
    let transcript: ConversationPresentation
    let showsRetry: Bool
    let isTyping: Bool
    let showsCancel: Bool
    let onTalk: () -> Void
    let onCancel: () -> Void
    let onType: () -> Void
    let onPractice: () -> Void
    @ViewBuilder var actions: () -> Actions

    private var talkTitle: String {
        if showsRetry { return "Try again" }
        return "Talk to NearMe"
    }

    private var talkEmphasis: ButtonEmphasis {
        if isTyping && !showsRetry { return .secondary }
        return .primary
    }

    var body: some View {
        ScreenScaffold(isGrouped: true) {
            VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
                homeControls
                if activity != .listening && (activity != .ready || transcript.hasContent) {
                    VoiceStateRow(activity: activity)
                }
                if transcript.hasContent { ConversationTranscript(presentation: transcript) }
                actions()
                practiceCard
            }
        }
    }

    private var homeControls: some View {
        HomeCard {
            Text("What would you like help with?")
                .font(TTFont.title())
                .accessibilityAddTraits(.isHeader)
            Text(HelpHomePresentation.hint).font(TTFont.body())
            VoiceOrbButton(state: state.micState, instruction: state.instruction,
                           title: talkTitle, emphasis: talkEmphasis, action: onTalk)
                .disabled(state.micDisabled)
            if showsCancel {
                PrimaryButton(title: "Cancel", systemImage: "xmark", emphasis: .secondary, action: onCancel)
            }
            if !isTyping || showsRetry {
                PrimaryButton(title: "Type instead", systemImage: "keyboard", emphasis: .secondary, action: onType)
            }
        }
    }

    private var practiceCard: some View {
        Button(action: onPractice) {
            HomeCard {
                HStack(alignment: .top, spacing: TTSpacing.relatedGap) {
                    Image(systemName: "tram.fill").accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
                        Text("Practise a train trip").font(TTFont.headline())
                        Text("Try a guided trip without booking.").font(TTFont.body())
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .foregroundStyle(TTColor.ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap, content: content)
            .fixedSize(horizontal: false, vertical: true)
            .padding(TTSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TTColor.readingSurface,
                        in: RoundedRectangle(cornerRadius: TTRadius.card, style: .continuous))
    }
}
