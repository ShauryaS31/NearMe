import SwiftUI

struct HelpHomeView: View {
    @ObservedObject var engine: TaskPlannerEngine
    @State private var request = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                #if DEBUG
                SessionDebugMenu(engine: engine)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                #endif
                Text("NearMe").font(.largeTitle)
                Button(action: engine.userTappedToTalk) {
                    Label("What do you need help with?", systemImage: "mic.fill")
                        .font(.title)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                Text("Try: 'Help me send a photo to Mum on WhatsApp'")
                    .font(.body)
                TextField("Type what you need help with", text: $request)
                    .font(.body)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit(send)
                Button(action: send) {
                    Label("Help me", systemImage: "hand.raised")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: engine.startPractice) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Practice mode", systemImage: "tram.fill").font(.title2)
                        Text("Practise planning a train trip, one step at a time.").font(.body)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
    }

    private func send() {
        guard !request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        engine.useTypedInput()
        engine.submitTypedInput(request)
        request = ""
    }
}

struct CoachView: View {
    @ObservedObject var engine: TaskPlannerEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    if let session = engine.coach {
                        CoachStepContent(session: session, onCommand: engine.coachCommand)
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
        .background(Color(.systemBackground))
    }

    private var stepAnimation: Animation? {
        if reduceMotion { return nil }
        return .easeInOut(duration: 0.2)
    }
}

/// Presentation shared by the card and its default-run assertions.
struct CoachStepPresentation {
    let session: CoachSession

    var countText: String { "Step \(session.stepIndex + 1) of \(session.count)" }
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
        VStack(alignment: .leading, spacing: 24) {
            Text(presentation.countText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(presentation.instruction)
                .font(.title2)
                .fixedSize(horizontal: false, vertical: true)
            Button { onCommand(.next) } label: {
                Label(presentation.doneTitle, systemImage: "checkmark")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            secondaryActions
        }
        .padding(24)
        .frame(maxWidth: 600, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    private var secondaryActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { onCommand(.repeatStep) } label: {
                Label("Repeat", systemImage: "arrow.counterclockwise").minimumTapTarget()
            }
            Button { onCommand(.stuck) } label: {
                Label("I'm stuck", systemImage: "questionmark.circle").minimumTapTarget()
            }
        }
        .buttonStyle(.bordered)
    }
}
