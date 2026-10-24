// Adapted from a prior prototype, used with permission.

import SwiftUI

struct PTVForYouView: View {
    let onTapJourneyPlanner: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PTVTopBar(title: "For you", trailing: "Log in")

            ScrollView {
                VStack(alignment: .leading, spacing: TTSpacing.lg) {
                    Text("Favourites")
                        .font(.system(.title3, design: .default).weight(.bold))
                        .foregroundStyle(PTVBrand.textPrimary)
                        .padding(.top, TTSpacing.md)

                    Button(action: onTapJourneyPlanner) {
                        HStack(spacing: TTSpacing.md) {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(PTVBrand.accent)
                                .frame(width: 40, height: 40)
                                .background(PTVBrand.accent.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Journey Planner")
                                    .font(TTFont.headline())
                                    .foregroundStyle(PTVBrand.textPrimary)
                                Text("Plan a trip across train, tram, bus & V/Line")
                                    .font(TTFont.caption())
                                    .foregroundStyle(PTVBrand.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(PTVBrand.textSecondary)
                        }
                        .padding(TTSpacing.md)
                        .background(PTVBrand.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(PTVBrand.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the journey planner")

                    ForEach(["Home", "Work", "Your location"], id: \.self) { row in
                        HStack {
                            Image(systemName: row == "Home" ? "house.fill" : row == "Work" ? "briefcase.fill" : "location.fill")
                                .foregroundStyle(PTVBrand.textSecondary)
                                .frame(width: 24)
                            Text(row)
                                .font(TTFont.body())
                                .foregroundStyle(PTVBrand.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, TTSpacing.sm)
                    }
                }
                .padding(.horizontal, TTSpacing.lg)
            }

            PTVTabBar(selected: .forYou)
        }
        .background(PTVBrand.background.ignoresSafeArea())
    }
}
