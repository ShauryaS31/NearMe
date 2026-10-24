#if DEBUG
import SwiftUI

private enum PolishPreviewScreen {
    case home, conversation(VoiceActivity), coach, welcome, explainer
}

/// Presentation-only fixtures: previews never request permissions, speech or a model.
private struct PolishPreview: View {
    let screen: PolishPreviewScreen

    var body: some View {
        switch screen {
        case .home:
            NavigationStack {
                HelpHomeContent(
                    state: SessionDockState(plannerState: .idle, isSpeaking: false, isStartingListening: false),
                    onTalk: {}, onType: {}, onPractice: {}
                )
                .navigationTitle("NearMe")
            }
        case .conversation(let activity):
            conversation(activity)
        case .coach:
            ScrollView { CoachStepContent(session: coach, onCommand: { _ in }) }
                .background(TTColor.groupedBackground)
        case .welcome:
            WelcomeContent(userName: "Shaurya", hour: 9, onStart: {})
        case .explainer:
            HowItWorksContent(onContinue: {})
        }
    }

    private func conversation(_ activity: VoiceActivity) -> some View {
        let turns: [ConversationTurn] = [
            ConversationTurn(speaker: .user, text: "I'd like to practise a train trip."),
            ConversationTurn(speaker: .nearme, text: "Where would you like to go?"),
            ConversationTurn(speaker: .user, text: "Town Hall"),
            ConversationTurn(speaker: .nearme, text: "Where will you start your journey?")
        ]
        let liveText = activity == .listening ? "From Central" : ""
        let presentation = ConversationPresentation(turns: turns, liveTranscript: liveText)
        let mic: VoiceOrbState = activity == .listening ? .listening : .idle
        return ConversationScreen(activity: activity, transcript: presentation) {
            VoiceOrbButton(state: mic, instruction: mic.instruction, action: {})
            PrimaryButton(title: "Type instead", systemImage: "keyboard", emphasis: .secondary, action: {})
            if activity == .speaking {
                PrimaryButton(title: "Stop", systemImage: "stop.fill", emphasis: .secondary, action: {})
            }
            PrimaryButton(title: "Cancel", systemImage: "xmark.circle", emphasis: .secondary, action: {})
        }
    }

    private var coach: CoachSession {
        CoachSession(guide: nil, request: "Send a photo", person: nil,
                     generalSteps: ["Open the app.", "Choose a conversation.", "Choose a photo.",
                                    "Review the photo.", "Add a message.", "Send the photo."],
                     stepIndex: 2, text: "Choose the photo you would like to send.")
    }
}

#Preview("Home / large / light") {
    PolishPreview(screen: .home)
        .dynamicTypeSize(.large)
        .preferredColorScheme(.light)
}

#Preview("Home / large / dark") {
    PolishPreview(screen: .home)
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
}

#Preview("Home / accessibility5 / light") {
    PolishPreview(screen: .home)
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Home / accessibility5 / dark") {
    PolishPreview(screen: .home)
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Conversation ready / large / light") {
    PolishPreview(screen: .conversation(.ready))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.light)
}

#Preview("Conversation ready / large / dark") {
    PolishPreview(screen: .conversation(.ready))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
}

#Preview("Conversation ready / accessibility5 / light") {
    PolishPreview(screen: .conversation(.ready))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Conversation ready / accessibility5 / dark") {
    PolishPreview(screen: .conversation(.ready))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Conversation listening / large / light") {
    PolishPreview(screen: .conversation(.listening))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.light)
}

#Preview("Conversation listening / large / dark") {
    PolishPreview(screen: .conversation(.listening))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
}

#Preview("Conversation listening / accessibility5 / light") {
    PolishPreview(screen: .conversation(.listening))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Conversation listening / accessibility5 / dark") {
    PolishPreview(screen: .conversation(.listening))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Conversation preparing / large / light") {
    PolishPreview(screen: .conversation(.preparing))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.light)
}

#Preview("Conversation preparing / large / dark") {
    PolishPreview(screen: .conversation(.preparing))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
}

#Preview("Conversation preparing / accessibility5 / light") {
    PolishPreview(screen: .conversation(.preparing))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Conversation preparing / accessibility5 / dark") {
    PolishPreview(screen: .conversation(.preparing))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Conversation speaking / large / light") {
    PolishPreview(screen: .conversation(.speaking))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.light)
}

#Preview("Conversation speaking / large / dark") {
    PolishPreview(screen: .conversation(.speaking))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
}

#Preview("Conversation speaking / accessibility5 / light") {
    PolishPreview(screen: .conversation(.speaking))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Conversation speaking / accessibility5 / dark") {
    PolishPreview(screen: .conversation(.speaking))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Conversation paused / large / light") {
    PolishPreview(screen: .conversation(.paused))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.light)
}

#Preview("Conversation paused / large / dark") {
    PolishPreview(screen: .conversation(.paused))
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
}

#Preview("Conversation paused / accessibility5 / light") {
    PolishPreview(screen: .conversation(.paused))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Conversation paused / accessibility5 / dark") {
    PolishPreview(screen: .conversation(.paused))
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Coach / large / light") {
    PolishPreview(screen: .coach)
        .dynamicTypeSize(.large)
        .preferredColorScheme(.light)
}

#Preview("Coach / large / dark") {
    PolishPreview(screen: .coach)
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
}

#Preview("Coach / accessibility5 / light") {
    PolishPreview(screen: .coach)
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Coach / accessibility5 / dark") {
    PolishPreview(screen: .coach)
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Welcome / large / light") {
    PolishPreview(screen: .welcome)
        .dynamicTypeSize(.large)
        .preferredColorScheme(.light)
}

#Preview("Welcome / large / dark") {
    PolishPreview(screen: .welcome)
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
}

#Preview("Welcome / accessibility5 / light") {
    PolishPreview(screen: .welcome)
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Welcome / accessibility5 / dark") {
    PolishPreview(screen: .welcome)
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Explainer / large / light") {
    PolishPreview(screen: .explainer)
        .dynamicTypeSize(.large)
        .preferredColorScheme(.light)
}

#Preview("Explainer / large / dark") {
    PolishPreview(screen: .explainer)
        .dynamicTypeSize(.large)
        .preferredColorScheme(.dark)
}

#Preview("Explainer / accessibility5 / light") {
    PolishPreview(screen: .explainer)
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.light)
}

#Preview("Explainer / accessibility5 / dark") {
    PolishPreview(screen: .explainer)
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#endif
