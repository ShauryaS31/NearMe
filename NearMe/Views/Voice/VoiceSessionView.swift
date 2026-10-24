// Adapted from a prior prototype, used with permission.

import SwiftUI

struct VoiceSessionView: View {
    @ObservedObject var engine: TaskPlannerEngine
    let onEndSession: () -> Void
    @State private var typedText = ""
    @FocusState private var textEntryFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScreenScaffold {
            VStack(spacing: TTSpacing.xl) {
                #if DEBUG
                SessionDebugMenu(engine: engine)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                #endif
                Spacer(minLength: TTSpacing.xxl)

                Text(statusLabel)
                    .font(TTFont.statusLabel())
                    .foregroundStyle(TTColor.accent)
                    .tracking(1.5)
                    .accessibilityHidden(true) // the orb already announces this via its own label

                if engine.plannerState == .thinking {
                    if reduceMotion {
                        Label("Thinking...", systemImage: "hourglass").font(.body)
                    } else {
                        ProgressView("Thinking...").font(.body)
                    }
                }

                VoiceOrbButton(state: orbState, instruction: orbInstruction, action: useVoiceInput)
                    .disabled(engine.plannerState == .finishing || engine.plannerState == .thinking || engine.isStartingListening)

                Text(subtitleText)
                    .font(TTFont.title())
                    .foregroundStyle(TTColor.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(subtitleAccessibilityLabel)

                if engine.isPreparingSpeech {
                    Label("Getting speech ready...", systemImage: "arrow.down.circle")
                        .font(.body)
                }
                if engine.isShowingPlaceSuggestions {
                    VStack(spacing: 12) {
                        Text("I heard: \(engine.suggestionTranscript)").font(.body)
                        Text(engine.suggestionQuestion).font(.title)
                        ForEach(engine.placeSuggestions, id: \.self) { place in
                            Button { engine.chooseSuggestedPlace(place) } label: {
                                Label(place, systemImage: "mappin.circle")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                        }
                        Button(action: engine.keepSuggestedPlace) {
                            Label("Keep what I said", systemImage: "checkmark")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        Button(action: engine.retrySuggestedPlace) {
                            Label("Say it again", systemImage: "mic")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                if let error = engine.lastErrorMessage {
                    Text(error)
                        .font(TTFont.callout())
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if engine.isTyping {
                    typedInputLayout {
                        TextField("Type your answer", text: $typedText)
                            .font(.body)
                            .textFieldStyle(.roundedBorder)
                            .focused($textEntryFocused)
                            .accessibilityLabel("Your answer")
                            .submitLabel(.send)
                            .onSubmit(sendTypedAnswer)
                        Button(action: useVoiceInput) {
                            Label("Use voice", systemImage: "mic")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(engine.plannerState != .idle)
                    }
                    Button(action: sendTypedAnswer) {
                        Label("Send", systemImage: "paperplane.fill")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSend)
                } else {
                    Button {
                        engine.useTypedInput()
                        textEntryFocused = true
                    } label: {
                        Label("Type instead", systemImage: "keyboard")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                PrimaryButton(title: buttonTitle) {
                    if engine.hasCompletedAtLeastOneJourney {
                        onEndSession()
                    } else {
                        engine.cancelCurrentAction()
                    }
                }
            }
            .frame(minHeight: 520)
        }
        .onChange(of: engine.isTyping) { _, isTyping in
            textEntryFocused = isTyping
        }
        .onAppear { textEntryFocused = engine.isTyping }
    }

    private var canSend: Bool {
        guard case .idle = engine.plannerState else { return false }
        return engine.isAwaitingSong || !typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var typedInputLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func sendTypedAnswer() {
        guard canSend else { return }
        engine.submitTypedInput(typedText)
        typedText = ""
        textEntryFocused = false
    }

    private func useVoiceInput() {
        textEntryFocused = false
        engine.userTappedToTalk()
    }

    private var buttonTitle: String {
        engine.hasCompletedAtLeastOneJourney ? "end session" : "cancel"
    }

    private var orbState: VoiceOrbState {
        switch engine.plannerState {
        case .listening: return .listening
        case .speaking: return .speaking
        case .thinking: return .idle
        default: return .idle
        }
    }

    private var orbInstruction: String {
        if engine.isStartingListening { return "Getting ready to listen..." }
        if engine.plannerState == .finishing { return "Finishing..." }
        return orbState.instruction
    }

    private var statusLabel: String {
        switch engine.plannerState {
        case .listening: return "LISTENING...."
        default: return "NearMe"
        }
    }

    private var subtitleText: String {
        switch engine.plannerState {
        case .speaking(let text):
            return text
        case .listening:
            if !engine.liveTranscript.isEmpty { return engine.liveTranscript }
            return engine.conversation.last?.text ?? "Listening..."
        case .thinking:
            return engine.liveTranscript.isEmpty ? "One moment..." : "Got it: \(engine.liveTranscript)"
        case .finishing:
            return engine.liveTranscript
        case .idle:
            if engine.isTyping {
                return engine.conversation.last(where: { $0.speaker == .nearme })?.text ?? "What would you like help with?"
            }
            return engine.lastErrorMessage == nil ? "Tap the mic to talk to NearMe." : "Tap the mic to try again."
        default:
            return ""
        }
    }

    private var subtitleAccessibilityLabel: String {
        switch engine.plannerState {
        case .listening: return "NearMe is listening. \(subtitleText)"
        default: return subtitleText
        }
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
