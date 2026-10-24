// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerForYouView: View {
    @ScaledMetric(relativeTo: .body) private var plannerIconSize = 22.0
    @ScaledMetric(relativeTo: .body) private var plannerIconFrame = 40.0
    let onTapJourneyPlanner: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TripPlannerTopBar(title: "For you", trailing: "Log in")

            Group {
                VStack(alignment: .leading, spacing: TTSpacing.lg) {
                    Text("Favourites")
                        .font(.system(.title3, design: .default).weight(.bold))
                        .foregroundStyle(Color.primary)
                        .padding(.top, TTSpacing.md)

                    Button(action: onTapJourneyPlanner) {
                        HStack(spacing: TTSpacing.md) {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                                .font(.system(size: plannerIconSize))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: plannerIconFrame, height: plannerIconFrame)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(PracticeLabels.journeyPlanner)
                                    .font(TTFont.headline())
                                    .foregroundStyle(Color.primary)
                                Text("Practise planning a public transport trip")
                                    .font(TTFont.caption())
                                    .foregroundStyle(Color.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(TTSpacing.md)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color(.separator))
                        )
                    }
                    .buttonStyle(.plain)
                    .practiceTarget(PracticeLabels.journeyPlanner, active: true, cornerRadius: 14)

                    ForEach(["Home", "Work", "Your location"], id: \.self) { row in
                        HStack {
                            Image(systemName: row == "Home" ? "house.fill" : row == "Work" ? "briefcase.fill" : "location.fill")
                                .foregroundStyle(Color.secondary)
                                .frame(width: 24)
                            Text(row)
                                .font(TTFont.body())
                                .foregroundStyle(Color.primary)
                            Spacer()
                        }
                        .padding(.vertical, TTSpacing.sm)
                    }
                }
                .padding(.horizontal, TTSpacing.lg)
            }

        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
