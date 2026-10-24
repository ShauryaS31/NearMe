// Adapted from a prior prototype, used with permission.

import SwiftUI

struct PTVDestinationSearchView: View {
    @ObservedObject var viewModel: PTVSimulationViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PTVTopBar(title: "Journey planner", onBack: onBack)

            VStack(alignment: .leading, spacing: TTSpacing.md) {
                Button {
                    if viewModel.step == .tapToAndTypeDestination {
                        viewModel.completeCurrentStep()
                    }
                } label: {
                    HStack(spacing: TTSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(PTVBrand.textSecondary)
                        Text(viewModel.destinationSearchQuery.isEmpty ? "Search for a destination" : viewModel.destinationSearchQuery)
                            .font(TTFont.body())
                            .foregroundStyle(viewModel.destinationSearchQuery.isEmpty ? PTVBrand.textSecondary : PTVBrand.textPrimary)
                        Spacer()
                        if !viewModel.destinationSearchQuery.isEmpty {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(PTVBrand.textSecondary)
                        }
                    }
                    .padding(TTSpacing.md)
                    .background(PTVBrand.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(viewModel.step == .tapToAndTypeDestination ? PTVBrand.accent : PTVBrand.hairline, lineWidth: viewModel.step == .tapToAndTypeDestination ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.step != .tapToAndTypeDestination)

                if viewModel.step == .selectingDestination {
                    Text("Train")
                        .font(TTFont.caption())
                        .foregroundStyle(PTVBrand.textSecondary)
                        .padding(.top, TTSpacing.sm)

                    Button {
                        viewModel.completeCurrentStep()
                    } label: {
                        HStack(spacing: TTSpacing.md) {
                            Image(systemName: "tram.fill")
                                .foregroundStyle(PTVBrand.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(viewModel.destinationDisplayName) Station")
                                    .font(TTFont.headline())
                                    .foregroundStyle(PTVBrand.textPrimary)
                                Text("in Melbourne City")
                                    .font(TTFont.caption())
                                    .foregroundStyle(PTVBrand.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(TTSpacing.md)
                        .background(PTVBrand.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(PTVBrand.accent, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(TTSpacing.lg)

            Spacer()
        }
        .background(PTVBrand.background.ignoresSafeArea())
    }
}
