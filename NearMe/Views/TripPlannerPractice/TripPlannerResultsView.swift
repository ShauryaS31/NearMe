// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerResultsView: View {
    @ObservedObject var viewModel: TripPlannerPracticeViewModel
    let onOpenMaps: () -> Void
    let onDone: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var openingFailed = false

    var body: some View {
        VStack(spacing: 0) {
            TripPlannerTopBar(title: "Journey details", onBack: viewModel.backToPlanner)
            VStack(alignment: .leading, spacing: TTSpacing.md) {
                Label(viewModel.fromFieldText, systemImage: "circle.fill")
                Label(viewModel.toFieldText, systemImage: "mappin")
                Label("Chosen departure", systemImage: "clock")
                Text(viewModel.departureDate.formatted(date: .abbreviated, time: .shortened))
                Text("Check transit options in Google Maps. Select this departure date and time there too. No timetables are shown here.")
                    .foregroundStyle(.secondary)
                Button {
                    guard let url = viewModel.transitDirectionsURL else { return }
                    openingFailed = false
                    onOpenMaps()
                    openURL(url) { accepted in openingFailed = !accepted }
                } label: {
                    Label(PracticeScreen.ResultsLabels.openMaps, systemImage: "map")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.transitDirectionsURL == nil)
                .practiceTarget(PracticeScreen.ResultsLabels.openMaps, active: true)
                if viewModel.transitDirectionsURL == nil {
                    Text("Edit the journey and use shorter, non-empty place names.")
                        .foregroundStyle(.secondary)
                }
                if openingFailed {
                    Text("Google Maps could not open. Try again or open Maps yourself and enter these places and departure time.")
                        .foregroundStyle(.secondary)
                }
                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            .font(.body)
            .padding(TTSpacing.lg)
        }
        .background(Color(.systemBackground))
    }
}
