// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerDestinationSearchView: View {
    @ObservedObject var viewModel: TripPlannerPracticeViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TripPlannerTopBar(title: PracticeLabels.journeyPlanner, onBack: onBack)

            VStack(alignment: .leading, spacing: TTSpacing.md) {
                Button {
                    if viewModel.step == .tapToAndTypeDestination {
                        viewModel.completeCurrentStep()
                    }
                } label: {
                    HStack(spacing: TTSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.secondary)
                        Text(viewModel.destinationSearchQuery.isEmpty ? PracticeLabels.searchDestination : viewModel.destinationSearchQuery)
                            .font(TTFont.body())
                            .foregroundStyle(viewModel.destinationSearchQuery.isEmpty ? Color.secondary : Color.primary)
                        Spacer()
                        if !viewModel.destinationSearchQuery.isEmpty {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .padding(TTSpacing.md)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(viewModel.step == .tapToAndTypeDestination ? Color.accentColor : Color(.separator), lineWidth: viewModel.step == .tapToAndTypeDestination ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.step != .tapToAndTypeDestination)

                if viewModel.step == .selectingDestination {
                    Text("Train")
                        .font(TTFont.caption())
                        .foregroundStyle(Color.secondary)
                        .padding(.top, TTSpacing.sm)

                    Button {
                        viewModel.completeCurrentStep()
                    } label: {
                        HStack(spacing: TTSpacing.md) {
                            Image(systemName: "tram.fill")
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(PracticeLabels.station(viewModel.destinationDisplayName))
                                    .font(TTFont.headline())
                                    .foregroundStyle(Color.primary)
                                Text("Practice destination")
                                    .font(TTFont.caption())
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                        }
                        .padding(TTSpacing.md)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(TTSpacing.lg)

            Spacer()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
