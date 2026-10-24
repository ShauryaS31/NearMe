// Adapted from a prior prototype, used with permission.

import SwiftUI

struct VoiceSessionView: View {
    @ObservedObject var engine: TaskPlannerEngine
    let onEndSession: () -> Void
    @State private var typedText = ""
    @State private var isPaused = false
    @FocusState private var textEntryFocused: Bool

    private var activity: VoiceActivity {
        VoiceActivity.resolve(plannerState: engine.plannerState, isSpeaking: engine.isVoiceOutputActive,
                              isPreparing: engine.isPreparingSpeech, isStartingListening: engine.isStartingListening,
                              isPaused: isPaused)
    }

    private var micState: SessionDockState {
        SessionDockState(plannerState: engine.plannerState, isSpeaking: engine.isVoiceOutputActive,
                         isStartingListening: engine.isStartingListening)
    }

    private var transcript: ConversationPresentation {
        let liveText: String
        switch engine.plannerState {
        case .listening, .finishing, .thinking: liveText = engine.liveTranscript
        default: liveText = ""
        }
        return ConversationPresentation(turns: engine.conversation, liveTranscript: liveText)
    }

    var body: some View {
        ConversationScreen(activity: activity, transcript: transcript) {
            if engine.isShowingPlaceSuggestions { placeSuggestions }
            if let error = engine.lastErrorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(TTFont.body())
                    .fixedSize(horizontal: false, vertical: true)
            }
            inputControls
            sessionActions
            #if DEBUG
            SessionDebugMenu(engine: engine)
                .frame(maxWidth: .infinity, alignment: .trailing)
            #endif
        }
        .onChange(of: engine.isTyping) { _, typing in textEntryFocused = typing }
        .onChange(of: engine.plannerState) { _, state in
            if state != .idle { isPaused = false }
        }
        .onAppear { textEntryFocused = engine.isTyping }
    }

    private var inputControls: some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            VoiceOrbButton(state: micState.micState, instruction: micState.instruction,
                           emphasis: engine.isTyping ? .secondary : .primary, action: useVoiceInput)
                .disabled(micState.micDisabled)
            if engine.isTyping {
                TextField("Type your answer", text: $typedText)
                    .font(TTFont.body())
                    .textFieldStyle(.roundedBorder)
                    .focused($textEntryFocused)
                    .accessibilityLabel("Your answer")
                    .submitLabel(.send)
                    .onSubmit(sendTypedAnswer)
                PrimaryButton(title: "Send", systemImage: "paperplane.fill", action: sendTypedAnswer)
                    .disabled(!canSend)
            } else {
                PrimaryButton(title: "Type instead", systemImage: "keyboard", emphasis: .secondary) {
                    isPaused = false
                    engine.useTypedInput()
                    textEntryFocused = true
                }
            }
        }
    }

    private var sessionActions: some View {
        AdaptiveButtonRow {
            if engine.isVoiceOutputActive || engine.isPreparingSpeech {
                PrimaryButton(title: "Stop", systemImage: "stop.fill", emphasis: .secondary) {
                    engine.stopSessionSpeech()
                    isPaused = true
                }
            }
            PrimaryButton(title: engine.hasCompletedAtLeastOneJourney ? "End session" : "Cancel",
                          systemImage: "xmark.circle", emphasis: .secondary) {
                if engine.hasCompletedAtLeastOneJourney {
                    onEndSession()
                } else {
                    engine.cancelCurrentAction()
                }
            }
        }
    }

    private var placeSuggestions: some View {
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

    private var canSend: Bool {
        guard case .idle = engine.plannerState else { return false }
        return !typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendTypedAnswer() {
        guard canSend else { return }
        isPaused = false
        engine.submitTypedInput(typedText)
        typedText = ""
        textEntryFocused = false
    }

    private func useVoiceInput() {
        isPaused = false
        textEntryFocused = false
        engine.userTappedToTalk()
    }
}

/// Read-only grouping; it never changes the engine's conversation or speech state.
struct ConversationPresentation {
    let userText: String?
    let replyText: String?
    let earlier: [ConversationTurn]

    init(turns: [ConversationTurn], liveTranscript: String) {
        let lastUserIndex: Int? = turns.lastIndex { $0.speaker == .user }
        let startIndex: Int = lastUserIndex ?? max(0, turns.count - 1)
        let current: [ConversationTurn] = Array(turns.dropFirst(startIndex))
        let lastReply: ConversationTurn? = current.last { $0.speaker == .nearme }
        let lastUser: ConversationTurn? = current.last { $0.speaker == .user }
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
}

struct ConversationScreen<Actions: View>: View {
    let activity: VoiceActivity
    let transcript: ConversationPresentation
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
                VoiceStateRow(activity: activity)
                ConversationTranscript(presentation: transcript)
                actions()
            }
        }
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

#if DEBUG
struct SessionDebugMenu: View {
    @ObservedObject var engine: TaskPlannerEngine

    var body: some View {
        Menu {
            Toggle("Show debug info", isOn: $engine.showsDebugInfo)
        } label: {
            Label("More", systemImage: "ellipsis.circle").minimumTapTarget()
        }
    }
}
#endif
