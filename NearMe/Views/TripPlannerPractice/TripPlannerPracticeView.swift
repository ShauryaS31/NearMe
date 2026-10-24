// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerPracticeView: View {
    @ObservedObject var viewModel: TripPlannerPracticeViewModel
    @ObservedObject var engine: TaskPlannerEngine

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ScrollViewReader { scroll in
                        ScrollView {
                            practiceScreen
                                .frame(maxWidth: .infinity)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .task(id: viewModel.step) {
                            await Task.yield()
                            scroll.scrollTo(viewModel.step.targetLabel(destination: viewModel.destinationDisplayName), anchor: .center)
                        }
                    }
                    .clipped()
                    TripPlannerTabBar(selected: viewModel.step.screen == .forYou ? .forYou : .plan)
                }
                .overlayPreferenceValue(PracticeTargetPreference.self) { targets in
                    PracticeHighlightLayer(targets: targets,
                        label: viewModel.step.targetLabel(destination: viewModel.destinationDisplayName),
                        repeatRevision: viewModel.highlightRepeatRevision)
                        .id(viewModel.step)
                }
                .clipped()

                SessionDock(engine: engine, instruction: viewModel.currentCaption,
                            targetLabel: nil, availableHeight: geometry.size.height)
            }
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var practiceScreen: some View {
        switch viewModel.step.screen {
        case .forYou:
            TripPlannerForYouView(onTapJourneyPlanner: { viewModel.completeCurrentStep() })
        case .journeyPlanner:
            TripPlannerJourneyPlannerView(viewModel: viewModel, onTapDestinationField: { viewModel.completeCurrentStep() })
        case .destinationSearch:
            TripPlannerDestinationSearchView(viewModel: viewModel, onBack: { })
        case .results:
            TripPlannerResultsView(origin: viewModel.originDisplayName, destination: viewModel.destinationDisplayName)
        }
    }
}
