// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerPracticeView: View {
    @ObservedObject var viewModel: TripPlannerPracticeViewModel
    var onRepeat: () -> Void = {}
    var onSlower: () -> Void = {}
    var onStop: () -> Void = {}
    var isSpeaking = false
    var plannerState: TaskPlannerState
    var isStartingListening = false
    var lastErrorMessage: String?
    var onTalk: () -> Void = {}
    var onTypeInstead: () -> Void = {}
    var onEndSession: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: TTSpacing.md) {
                CaptionBubble(text: viewModel.currentCaption, onDismiss: nil)
                    .padding(.horizontal, TTSpacing.md)
                VoiceOrbButton(state: orbState, instruction: orbInstruction, action: onTalk)
                    .disabled(plannerState == .finishing || plannerState == .thinking || isStartingListening)
                if let lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Group {
                    switch viewModel.step.screen {
                    case .forYou:
                        TripPlannerForYouView(onTapJourneyPlanner: { viewModel.completeCurrentStep() })
                    case .journeyPlanner:
                        TripPlannerJourneyPlannerView(viewModel: viewModel, onTapDestinationField: { viewModel.completeCurrentStep() })
                    case .destinationSearch:
                        TripPlannerDestinationSearchView(viewModel: viewModel, onBack: { /* simulation only moves forward */ })
                    case .results:
                        TripPlannerResultsView(origin: viewModel.originDisplayName, destination: viewModel.destinationDisplayName)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: viewModel.step)

                VStack(spacing: 12) {
                    Button(action: onRepeat) { Label("Repeat", systemImage: "arrow.counterclockwise").minimumTapTarget() }
                    Button(action: onSlower) { Label("Slower", systemImage: "tortoise").minimumTapTarget() }
                    Button(action: onStop) { Label("Stop", systemImage: "stop.fill").minimumTapTarget() }
                    Button(action: onTypeInstead) { Label("Type instead", systemImage: "keyboard").minimumTapTarget() }
                    Button(action: onEndSession) { Label("End session", systemImage: "xmark.circle").minimumTapTarget() }
                }
                .font(.body)
                .buttonStyle(.bordered)
                .padding(.bottom, TTSpacing.lg)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityElement(children: .contain)
    }

    private var orbState: VoiceOrbState {
        if plannerState == .listening { return .listening }
        return isSpeaking ? .speaking : .idle
    }

    private var orbInstruction: String {
        if isStartingListening { return "Getting ready to listen..." }
        if plannerState == .finishing { return "Finishing..." }
        return orbState.instruction
    }
}
