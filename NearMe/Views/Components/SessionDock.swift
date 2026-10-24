import SwiftUI

enum SessionDockAction: String, CaseIterable, Identifiable {
    case repeatStep, slower, typeInstead, endSession

    var id: Self { self }
    var title: String {
        switch self {
        case .repeatStep: return "Repeat"
        case .slower: return "Slower"
        case .typeInstead: return "Type instead"
        case .endSession: return "End session"
        }
    }
    var symbol: String {
        switch self {
        case .repeatStep: return "arrow.counterclockwise"
        case .slower: return "tortoise"
        case .typeInstead: return "keyboard"
        case .endSession: return "xmark.circle"
        }
    }
}

/// The same state contract as the P04b mic, without the large orb.
struct SessionDockState {
    let plannerState: TaskPlannerState
    let isSpeaking: Bool
    let isStartingListening: Bool

    var showsStop: Bool { isSpeaking }
    var micDisabled: Bool {
        plannerState == .thinking || plannerState == .finishing || isStartingListening
    }
    var micState: VoiceOrbState {
        if plannerState == .listening { return .listening }
        return isSpeaking ? .speaking : .idle
    }
    var instruction: String {
        if isStartingListening { return "Getting ready to listen..." }
        if plannerState == .finishing { return "Finishing..." }
        return micState.instruction
    }
}

struct SessionDock: View {
    @ObservedObject var engine: TaskPlannerEngine
    let instruction: String
    let targetLabel: String?
    let availableHeight: CGFloat
    @State private var contentHeight: CGFloat = 72
    @State private var controlsHeight: CGFloat = 44
    @State private var typedText = ""
    @FocusState private var entryFocused: Bool

    private var state: SessionDockState {
        SessionDockState(plannerState: engine.plannerState, isSpeaking: engine.isVoiceOutputActive,
                         isStartingListening: engine.isStartingListening)
    }

    private var styledInstruction: AttributedString {
        var text = AttributedString(instruction)
        if let targetLabel, let range = text.range(of: targetLabel) {
            text[range].swiftUI.font = .title3.bold()
        }
        return text
    }

    var body: some View {
        VStack(spacing: 8) {
            instructionArea
            controls
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(TTColor.background)
        .tint(TTColor.accent)
        .overlay(alignment: .top) { Divider() }
        .onChange(of: engine.isTyping) { _, typing in entryFocused = typing }
    }

    private var instructionArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(styledInstruction)
                    .font(.title3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Only the caption changes identity; typing focus and draft survive.
                    .id(instruction)
                if engine.plannerState == .listening && !engine.liveTranscript.isEmpty {
                    Text(engine.liveTranscript)
                        .font(.title3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error = engine.lastErrorMessage {
                    Text(error).font(.body).fixedSize(horizontal: false, vertical: true)
                }
                if engine.isTyping { typedEntry }
            }
            .padding(4)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(engine.isTyping ? .bottom : .top)
        .frame(height: min(contentHeight, max(44, availableHeight * 0.4 - controlsHeight - 32)))
        .background(TTColor.readingSurface)
    }

    private var typedEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Type your answer", text: $typedText)
                .font(.body)
                .textFieldStyle(.roundedBorder)
                .focused($entryFocused)
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Label("Send", systemImage: "paperplane.fill").minimumTapTarget()
            }
            .disabled(!canSend)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            microphone
            Text(state.instruction)
                .font(TTFont.body())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if state.showsStop { stopButton }
            moreMenu
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controlsHeight = $0 }
    }

    private var microphone: some View {
        Button {
            entryFocused = false
            engine.userTappedToTalk()
        } label: {
            Image(systemName: state.micState.symbolName)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(state.micState.accessibilityLabel)
        .accessibilityHint(state.instruction)
        .disabled(state.micDisabled)
    }

    private var stopButton: some View {
        Button(action: engine.stopSessionSpeech) {
            Label("Stop", systemImage: "stop.fill")
                .minimumTapTarget()
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Stop")
    }

    private var moreMenu: some View {
        Menu {
            ForEach(SessionDockAction.allCases) { action in
                Button { engine.performDockAction(action) } label: {
                    Label(action.title, systemImage: action.symbol)
                }
            }
            #if DEBUG
            Toggle("Show debug info", isOn: $engine.showsDebugInfo)
            #endif
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
    }

    private var canSend: Bool {
        engine.canSubmitTypedInput && !typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private func send() {
        guard canSend else { return }
        engine.submitTypedInput(typedText)
        typedText = ""
        entryFocused = false
    }
}
