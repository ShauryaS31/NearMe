// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerForYouView: View {
    let onTapJourneyPlanner: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TripPlannerTopBar(title: "For you", trailing: "Log in")

            ScrollView {
                VStack(alignment: .leading, spacing: TTSpacing.lg) {
                    Text("Favourites")
                        .font(.system(.title3, design: .default).weight(.bold))
                        .foregroundStyle(Color.primary)
                        .padding(.top, TTSpacing.md)

                    Button(action: onTapJourneyPlanner) {
                        HStack(spacing: TTSpacing.md) {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 40, height: 40)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Journey Planner")
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
                    .accessibilityHint("Opens the journey planner")

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

            TripPlannerTabBar(selected: .forYou)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
