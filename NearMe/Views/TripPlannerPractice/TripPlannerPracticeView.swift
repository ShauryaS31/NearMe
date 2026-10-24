// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerPracticeView: View {
    @ObservedObject var viewModel: TripPlannerPracticeViewModel
    var onDismissCaption: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
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

            CaptionBubble(text: viewModel.currentCaption, onDismiss: onDismissCaption)
                .padding(.horizontal, TTSpacing.md)
                .padding(.bottom, TTSpacing.lg)
        }
        .accessibilityElement(children: .contain)
    }
}
