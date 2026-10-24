import SwiftUI

struct HelpHomeView: View {
    @ObservedObject var engine: TaskPlannerEngine

    private var micState: SessionDockState {
        SessionDockState(plannerState: engine.plannerState, isSpeaking: engine.isVoiceOutputActive,
                         isStartingListening: engine.isStartingListening)
    }

    var body: some View {
        NavigationStack {
            HelpHomeContent(state: micState, onTalk: engine.userTappedToTalk,
                            onType: engine.useTypedInput, onPractice: engine.startPractice)
                .navigationTitle("NearMe")
                #if DEBUG
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        SessionDebugMenu(engine: engine)
                    }
                }
                #endif
        }
        .tint(TTColor.accent)
    }
}

struct HelpHomeContent: View {
    let state: SessionDockState
    let onTalk: () -> Void
    let onType: () -> Void
    let onPractice: () -> Void

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
                Text("What would you like help with?")
                    .font(TTFont.title())
                    .accessibilityAddTraits(.isHeader)
                Text("Try: help me send a photo to Mum")
                    .font(TTFont.body())
                VoiceOrbButton(state: state.micState, instruction: state.instruction, action: onTalk)
                    .disabled(state.micDisabled)
                PrimaryButton(title: "Type instead", systemImage: "keyboard", emphasis: .secondary,
                              action: onType)
                PrimaryButton(title: "Practise a train trip", systemImage: "tram.fill", emphasis: .secondary,
                              action: onPractice)
            }
        }
    }
}

struct CoachView: View {
    @ObservedObject var engine: TaskPlannerEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsHelp = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    if let session = engine.coach {
                        CoachStepContent(session: session, onCommand: command)
                            .id(session.stepIndex)
                            .transition(.opacity)
                    }
                }
                .animation(stepAnimation, value: engine.coach?.stepIndex)
                if let session = engine.coach {
                    SessionDock(engine: engine, instruction: session.text,
                                targetLabel: session.guide?.steps[session.stepIndex].uiLabelHint,
                                availableHeight: geometry.size.height)
                }
            }
        }
        .background(TTColor.groupedBackground)
        .tint(TTColor.accent)
        .sheet(isPresented: $showsHelp) {
            CoachHelpSheet(engine: engine)
                .presentationDetents([.large])
        }
        .onChange(of: engine.coach?.id) { _, id in
            if id == nil { showsHelp = false }
        }
    }

    private func command(_ command: CoachCommand) {
        if command == .stuck { showsHelp = true }
        engine.coachCommand(command)
    }

    private var stepAnimation: Animation? {
        if reduceMotion { return nil }
        return .easeInOut(duration: 0.2)
    }
}

/// Presentation shared by the card and its default-run assertions.
struct CoachStepPresentation {
    let session: CoachSession

    var title: String {
        if let guide = session.guide { return guide.title }
        return session.request.isEmpty ? "Your next step" : session.request
    }
    var countText: String { "Step \(session.stepIndex + 1) of \(session.count)" }
    var hasKnownTotal: Bool { session.count > 0 }
    var completedSteps: Double { Double(session.stepIndex) }
    var totalSteps: Double { Double(session.count) }
    var doneTitle: String { "Done" }
    var instruction: AttributedString {
        var text = AttributedString(session.text)
        if let label = session.guide?.steps[session.stepIndex].uiLabelHint,
           let range = text.range(of: label) {
            text[range].swiftUI.font = .title2.bold()
        }
        return text
    }
}

struct CoachStepContent: View {
    let session: CoachSession
    let onCommand: (CoachCommand) -> Void

    private var presentation: CoachStepPresentation { CoachStepPresentation(session: session) }

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
            Text(presentation.title)
                .font(TTFont.title())
                .accessibilityAddTraits(.isHeader)
            if presentation.hasKnownTotal {
                progress
            }
            Text(presentation.instruction)
                .font(TTFont.title())
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: presentation.doneTitle, systemImage: "checkmark") { onCommand(.next) }
            AdaptiveButtonRow {
                PrimaryButton(title: "Repeat", systemImage: "arrow.counterclockwise", emphasis: .secondary) {
                    onCommand(.repeatStep)
                }
                PrimaryButton(title: "I'm stuck", systemImage: "questionmark.circle", emphasis: .secondary) {
                    onCommand(.stuck)
                }
            }
        }
        .padding(TTSpacing.cardPadding)
        .frame(maxWidth: 600, alignment: .leading)
        .background(TTColor.readingSurface,
                    in: RoundedRectangle(cornerRadius: TTRadius.card, style: .continuous))
        .padding(TTSpacing.screenInset)
        .frame(maxWidth: .infinity)
        .tint(TTColor.accent)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            Text(presentation.countText).font(TTFont.body())
            ProgressView(value: presentation.completedSteps, total: presentation.totalSteps)
                .accessibilityLabel("Completed steps")
                .accessibilityValue("\(session.stepIndex) of \(session.count)")
        }
    }
}

private struct CoachHelpSheet: View {
    @ObservedObject var engine: TaskPlannerEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScreenScaffold {
                VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
                    if engine.plannerState == .thinking || engine.isPreparingSpeech {
                        VoiceStateRow(activity: .preparing)
                    }
                    if let session = engine.coach {
                        Text(session.text)
                            .font(TTFont.title())
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(TTSpacing.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(TTColor.readingSurface,
                                        in: RoundedRectangle(cornerRadius: TTRadius.card, style: .continuous))
                    }
                    PrimaryButton(title: "Repeat", systemImage: "arrow.counterclockwise", emphasis: .secondary) {
                        engine.coachCommand(.repeatStep)
                    }
                    PrimaryButton(title: "Slower", systemImage: "tortoise", emphasis: .secondary) {
                        engine.coachCommand(.slower)
                    }
                    PrimaryButton(title: "Stop", systemImage: "stop.fill", emphasis: .secondary,
                                  action: engine.stopSessionSpeech)
                    PrimaryButton(title: "Close", systemImage: "xmark", emphasis: .secondary) { dismiss() }
                }
            }
            .navigationTitle("I'm stuck")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                }
            }
        }
        .tint(TTColor.accent)
    }
}
