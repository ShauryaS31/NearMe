// Adapted from a prior prototype, used with permission.

import SwiftUI

struct PTVJourneyPlannerView: View {
    @ObservedObject var viewModel: PTVSimulationViewModel
    let onTapDestinationField: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PTVTopBar(title: "Journey planner")

            VStack(alignment: .leading, spacing: TTSpacing.md) {
                fieldRow(
                    icon: "circle.fill",
                    iconColor: PTVBrand.accent,
                    placeholder: "Choose origin",
                    value: viewModel.fromFieldText,
                    isHighlighted: viewModel.step == .tapFrom,
                    action: viewModel.step == .tapFrom ? { viewModel.completeCurrentStep() } : nil
                )

                fieldRow(
                    icon: "mappin",
                    iconColor: PTVBrand.primary,
                    placeholder: "Choose destination",
                    value: viewModel.toFieldText,
                    isHighlighted: viewModel.step == .typeOrigin,
                    action: viewModel.step == .typeOrigin ? onTapDestinationField : nil
                )

                HStack {
                    Label("Depart Now", systemImage: "clock")
                        .font(TTFont.callout())
                        .foregroundStyle(PTVBrand.textSecondary)
                    Spacer()
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(PTVBrand.textSecondary)
                }
                .padding(.top, TTSpacing.xs)

                if viewModel.step == .readyToSearch {
                    Button(action: { viewModel.completeCurrentStep() }) {
                        Text("Search")
                            .font(TTFont.headline())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TTSpacing.md)
                    }
                    .background(PTVBrand.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.top, TTSpacing.sm)
                }

                Spacer()
            }
            .padding(TTSpacing.lg)

            Spacer()
        }
        .background(PTVBrand.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func fieldRow(icon: String, iconColor: Color, placeholder: String, value: String, isHighlighted: Bool, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: TTSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(iconColor)
                Text(value.isEmpty ? placeholder : value)
                    .font(TTFont.body())
                    .foregroundStyle(value.isEmpty ? PTVBrand.textSecondary : PTVBrand.textPrimary)
                Spacer()
            }
            .padding(TTSpacing.md)
            .background(PTVBrand.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isHighlighted ? PTVBrand.accent : PTVBrand.hairline, lineWidth: isHighlighted ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
