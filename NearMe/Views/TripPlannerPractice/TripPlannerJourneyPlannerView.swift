// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerJourneyPlannerView: View {
    @ObservedObject var viewModel: TripPlannerPracticeViewModel
    let onTapDestinationField: () -> Void
    @FocusState private var originFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TripPlannerTopBar(title: PracticeScreen.ForYouLabels.journeyPlanner)
            VStack(alignment: .leading, spacing: TTSpacing.md) {
                Label(PracticeScreen.JourneyPlannerLabels.chooseOrigin, systemImage: "circle.fill")
                    .font(TTFont.headline())
                TextField("Type a place or station", text: $viewModel.fromFieldText)
                    .font(TTFont.body())
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .focused($originFocused)
                    .submitLabel(.next)
                    .accessibilityLabel(PracticeScreen.JourneyPlannerLabels.chooseOrigin)
                    .onSubmit { submitOrigin() }
                    .practiceTarget(PracticeScreen.JourneyPlannerLabels.chooseOrigin, active: viewModel.step == .tapFrom)
                    .frame(minHeight: 44)

                if viewModel.step == .tapFrom {
                    Button(action: submitOrigin) {
                        Label("Continue", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canContinueOrigin)
                } else {
                    Button {
                        originFocused = false
                        onTapDestinationField()
                    } label: {
                        VStack(alignment: .leading, spacing: TTSpacing.xs) {
                            Label(PracticeScreen.JourneyPlannerLabels.chooseDestination, systemImage: "mappin")
                            if !viewModel.toFieldText.isEmpty {
                                Text(viewModel.toFieldText).foregroundStyle(.primary)
                            }
                        }
                        .font(TTFont.body())
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canContinueOrigin)
                    .practiceTarget(PracticeScreen.JourneyPlannerLabels.chooseDestination, active: viewModel.step == .typeOrigin)
                }

                if viewModel.step == .readyToSearch {
                    DatePicker("Depart at", selection: $viewModel.departureDate, in: Date()...,
                               displayedComponents: [.date, .hourAndMinute])
                        .font(TTFont.body())
                        .datePickerStyle(.compact)
                    Text("Choose this departure time in Google Maps too. Times use your iPhone's time zone.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Button {
                        originFocused = false
                        viewModel.completeCurrentStep()
                    } label: {
                        Label(PracticeScreen.JourneyPlannerLabels.search, systemImage: "arrow.right")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canReview)
                    .practiceTarget(PracticeScreen.JourneyPlannerLabels.search, active: true)
                }
            }
            .padding(TTSpacing.lg)
        }
        .background(Color(.systemBackground))
    }

    private func submitOrigin() {
        guard viewModel.canContinueOrigin else { return }
        originFocused = false
        if viewModel.step == .tapFrom { viewModel.completeCurrentStep() }
    }
}
