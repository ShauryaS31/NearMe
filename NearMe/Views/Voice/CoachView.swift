import SwiftUI
import UIKit

struct HelpHomeView: View {
    @ObservedObject var engine: TaskPlannerEngine
    @State private var request = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Reserved for P05's Settings gear in the top trailing area.
                Color.clear.frame(height: 44).accessibilityHidden(true)
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

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    if let session = engine.coach {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(session.guide?.title ?? "Phone help").font(.title)
                            Text("Step \(session.stepIndex + 1) of \(session.count)").font(.body)
                            if session.isGeneral {
                                Label("General guidance: your screen may look different", systemImage: "info.circle")
                            }
                            #if DEBUG
                            if session.needsScreenCheck {
                                Label("Check on your screen", systemImage: "checkmark.rectangle").font(.caption)
                            }
                            #endif
                            if engine.plannerState == .thinking {
                                Label("Preparing your step", systemImage: "hourglass")
                            } else if engine.plannerState == .listening {
                                Label("Listening", systemImage: "mic.fill")
                                Text(engine.liveTranscript)
                            } else if engine.plannerState == .finishing {
                                Label("Finishing", systemImage: "hourglass")
                            } else if engine.isStartingListening || engine.isPreparingSpeech {
                                Label("Getting speech ready", systemImage: "mic")
                            } else {
                                Label(engine.isVoiceOutputActive ? "Speaking" : "Ready",
                                      systemImage: engine.isVoiceOutputActive ? "speaker.wave.2" : "checkmark.circle")
                            }
                            action("Done / Next", symbol: "checkmark", command: .next)
                            action("I'm stuck", symbol: "questionmark.circle", command: .stuck)
                            if let guide = session.guide, let url = launchURL(guide) {
                                Button { UIApplication.shared.open(url) } label: {
                                    Label("Open \(guide.app)", systemImage: "arrow.up.forward.app")
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .font(.body)
                        .padding()
                        .frame(maxWidth: 600, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                }
                if let session = engine.coach {
                    SessionDock(engine: engine, instruction: session.text,
                                targetLabel: session.guide?.steps[session.stepIndex].uiLabelHint,
                                availableHeight: geometry.size.height)
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private func action(_ title: String, symbol: String, command: CoachCommand) -> some View {
        Button { engine.coachCommand(command) } label: {
            Label(title, systemImage: symbol).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private func launchURL(_ guide: HelpGuide) -> URL? {
        guard let scheme = guide.appURLScheme, ["whatsapp://", "sms:"].contains(scheme),
              let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) else { return nil }
        return url
    }
}
