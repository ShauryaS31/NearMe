// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerPracticeView: View {
    @ObservedObject var viewModel: TripPlannerPracticeViewModel
    var onRepeat: () -> Void = {}
    var onSlower: () -> Void = {}
    var onStop: () -> Void = {}
    var isSpeaking = false
    var onTalk: () -> Void = {}
    var onTypeInstead: () -> Void = {}
    var onEndSession: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: TTSpacing.md) {
                CaptionBubble(text: viewModel.currentCaption, onDismiss: nil)
                    .padding(.horizontal, TTSpacing.md)
                VoiceOrbButton(state: isSpeaking ? .speaking : .idle, action: onTalk)
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
}
