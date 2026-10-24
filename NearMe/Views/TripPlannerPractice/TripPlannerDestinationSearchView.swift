// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerDestinationSearchView: View {
    @ObservedObject var viewModel: TripPlannerPracticeViewModel
    let onBack: () -> Void
    @FocusState private var destinationFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TripPlannerTopBar(title: PracticeScreen.ForYouLabels.journeyPlanner, onBack: onBack)
            VStack(alignment: .leading, spacing: TTSpacing.md) {
                Label(PracticeScreen.DestinationSearchLabels.searchDestination, systemImage: "magnifyingglass")
                    .font(TTFont.headline())
                TextField("Type a place or station", text: $viewModel.destinationSearchQuery)
                    .font(TTFont.body())
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .focused($destinationFocused)
                    .submitLabel(.done)
                    .onSubmit { submitDestination() }
                    .accessibilityLabel(PracticeScreen.DestinationSearchLabels.searchDestination)
                    .practiceTarget(PracticeScreen.DestinationSearchLabels.searchDestination,
                                    active: viewModel.step == .tapToAndTypeDestination)
                    .frame(minHeight: 44)
                Text("Include the city if the place name could mean more than one location.")
                    .font(.body).foregroundStyle(.secondary)
                if viewModel.step == .tapToAndTypeDestination {
                    Button(action: submitDestination) {
                        Label("Continue", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canContinueDestination)
                } else {
                    Button {
                        destinationFocused = false
                        viewModel.completeCurrentStep()
                    } label: {
                        Label(PracticeScreen.DestinationSearchLabels.station(viewModel.destinationDisplayName),
                              systemImage: "checkmark")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canContinueDestination)
                    .practiceTarget(PracticeScreen.DestinationSearchLabels.station(viewModel.destinationDisplayName), active: true)
                    Text("Google Maps will find this place. Check that it selects the right location.")
                        .font(.body).foregroundStyle(.secondary)
                }
            }
            .padding(TTSpacing.lg)
        }
        .background(Color(.systemBackground))
    }

    private func submitDestination() {
        guard viewModel.canContinueDestination else { return }
        destinationFocused = false
        if viewModel.step == .tapToAndTypeDestination { viewModel.completeCurrentStep() }
    }
}
