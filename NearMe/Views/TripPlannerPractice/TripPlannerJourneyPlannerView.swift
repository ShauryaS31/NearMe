// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerJourneyPlannerView: View {
    @ScaledMetric(relativeTo: .body) private var fieldIconSize = 10.0
    @ObservedObject var viewModel: TripPlannerPracticeViewModel
    let onTapDestinationField: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TripPlannerTopBar(title: PracticeScreen.ForYouLabels.journeyPlanner)

            VStack(alignment: .leading, spacing: TTSpacing.md) {
                fieldRow(
                    icon: "circle.fill",
                    iconColor: Color.accentColor,
                    placeholder: PracticeScreen.JourneyPlannerLabels.chooseOrigin,
                    value: viewModel.fromFieldText,
                    isHighlighted: viewModel.step == .tapFrom,
                    action: viewModel.step == .tapFrom ? { viewModel.completeCurrentStep() } : nil
                )

                fieldRow(
                    icon: "mappin",
                    iconColor: Color.primary,
                    placeholder: PracticeScreen.JourneyPlannerLabels.chooseDestination,
                    value: viewModel.toFieldText,
                    isHighlighted: viewModel.step == .typeOrigin,
                    action: viewModel.step == .typeOrigin ? onTapDestinationField : nil
                )

                HStack {
                    Label("Depart Now", systemImage: "clock")
                        .font(TTFont.callout())
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.secondary)
                }
                .padding(.top, TTSpacing.xs)

                if viewModel.step == .readyToSearch {
                    Button(action: { viewModel.completeCurrentStep() }) {
                        Text(PracticeScreen.JourneyPlannerLabels.search)
                            .font(TTFont.headline())
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TTSpacing.md)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    )
                    .practiceTarget(PracticeScreen.JourneyPlannerLabels.search, active: true, cornerRadius: 14)
                    .padding(.top, TTSpacing.sm)
                }

                Spacer()
            }
            .padding(TTSpacing.lg)

            Spacer()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    @ViewBuilder
    private func fieldRow(icon: String, iconColor: Color, placeholder: String, value: String, isHighlighted: Bool, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: TTSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: fieldIconSize))
                    .foregroundStyle(iconColor)
                Text(value.isEmpty ? placeholder : value)
                    .font(TTFont.body())
                    .foregroundStyle(value.isEmpty ? Color.secondary : Color.primary)
                Spacer()
            }
            .padding(TTSpacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isHighlighted ? Color.accentColor : Color(.separator), lineWidth: isHighlighted ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .practiceTarget(placeholder, active: isHighlighted)
    }
}
