// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerResultsView: View {
    let origin: String
    let destination: String

    var body: some View {
        VStack(spacing: 0) {
            TripPlannerTopBar(title: PracticeLabels.journeyPlanner)

            VStack(alignment: .leading, spacing: TTSpacing.xs) {
                Text(PracticeLabels.tripOptions)
                    .font(.title2.bold())
                    .padding()
                    .practiceTarget(PracticeLabels.tripOptions, active: true)
                Text("\(origin) \u{2192} \(destination)")
                    .font(TTFont.headline())
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, TTSpacing.lg)
                    .padding(.top, TTSpacing.md)

                Group {
                    VStack(spacing: TTSpacing.sm) {
                        ForEach(1...3, id: \.self) { number in
                            HStack(alignment: .top, spacing: TTSpacing.md) {
                                Image(systemName: "tram.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Trip option \(number) (example)")
                                        .font(TTFont.headline())
                                        .foregroundStyle(Color.primary)
                                    Text("Times show here in the real app")
                                        .font(.body)
                                        .foregroundStyle(Color.secondary)
                                }

                                Spacer()
                            }
                            .padding(TTSpacing.md)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color(.separator), lineWidth: 1)
                            )
                        }
                    }
                    .padding(TTSpacing.lg)
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
