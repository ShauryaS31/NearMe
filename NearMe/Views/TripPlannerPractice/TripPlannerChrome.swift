// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerTopBar: View {
    var title: String
    var trailing: String? = nil
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .minimumTapTarget()
                .accessibilityLabel("Back")
            }

            VStack(alignment: .leading, spacing: TTSpacing.xs) {
                Text("Trip planner")
                    .font(.system(.title2, design: .default).weight(.bold))
                Label("Practice", systemImage: "hand.tap")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(TTFont.headline())
            }

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(TTFont.callout())
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, TTSpacing.lg)
        .padding(.vertical, TTSpacing.md)
        .background(Color(.secondarySystemBackground))
    }
}

enum TripPlannerTab: CaseIterable {
    case forYou, plan, search, alerts, settings

    var symbol: String {
        switch self {
        case .forYou: return "person.crop.circle"
        case .plan: return "point.topleft.down.curvedto.point.bottomright.up.fill"
        case .search: return "magnifyingglass"
        case .alerts: return "bell"
        case .settings: return "line.3.horizontal"
        }
    }

    var label: String {
        switch self {
        case .forYou: return "For you"
        case .plan: return "Plan"
        case .search: return "Search"
        case .alerts: return "Alerts"
        case .settings: return "Settings"
        }
    }
}

struct TripPlannerTabBar: View {
    var selected: TripPlannerTab

    var body: some View {
        HStack {
            ForEach(TripPlannerTab.allCases, id: \.self) { tab in
                VStack(spacing: 3) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 19))
                    Text(tab.label)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(tab == selected ? Color.accentColor : Color.secondary)
                .frame(maxWidth: .infinity)
                .minimumTapTarget()
            }
        }
        .padding(.vertical, TTSpacing.sm)
        .background(
            Color(.secondarySystemBackground)
                .overlay(Rectangle().fill(Color(.separator)).frame(height: 0.5), alignment: .top)
        )
        .accessibilityHidden(true) // decorative in v1 — not functionally navigable
    }
}
