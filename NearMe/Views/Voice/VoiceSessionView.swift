// Adapted from a prior prototype, used with permission.

import SwiftUI

struct VoiceSessionView: View {
    @ObservedObject var engine: TaskPlannerEngine
    let onEndSession: () -> Void
    @State private var typedText = ""
    @FocusState private var textEntryFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScreenScaffold {
            VStack(spacing: TTSpacing.xl) {
                Spacer(minLength: TTSpacing.xxl)

                Text(statusLabel)
                    .font(TTFont.statusLabel())
                    .foregroundStyle(TTColor.accent)
                    .tracking(1.5)
                    .accessibilityHidden(true) // the orb already announces this via its own label

                VoiceOrbView(state: orbState)
                    .onTapGesture {
                        if case .idle = engine.plannerState {
                            useVoiceInput()
                        }
                    }

                Text(subtitleText)
                    .font(TTFont.title())
                    .foregroundStyle(TTColor.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(subtitleAccessibilityLabel)

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
    }

    private var canSend: Bool {
        guard case .idle = engine.plannerState else { return false }
        return !typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        case .speaking, .thinking: return .speaking
        default: return .idle
        }
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
            return engine.conversation.last?.text ?? "One moment..."
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
