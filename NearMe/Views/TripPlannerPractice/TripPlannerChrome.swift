// Adapted from a prior prototype, used with permission.

import SwiftUI

struct TripPlannerTopBar: View {
    @ScaledMetric(relativeTo: .body) private var backIconSize = 17.0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var title: String
    var trailing: String? = nil
    var onBack: (() -> Void)? = nil

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout())
        layout {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: backIconSize, weight: .semibold))
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
        case .search: return PracticeLabels.search
        case .alerts: return "Alerts"
        case .settings: return "Settings"
        }
    }
}

struct TripPlannerTabBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var tappedTab: TripPlannerTab?
    var selected: TripPlannerTab

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal) {
                    tabs
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                tabs
            }
        }
        .padding(.vertical, TTSpacing.sm)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .top) { Divider() }
        .alert(tappedTab?.label ?? "Practice", isPresented: Binding(
            get: { tappedTab != nil }, set: { if !$0 { tappedTab = nil } }
        )) {
            Button("Continue practice", role: .cancel) { tappedTab = nil }
        } message: {
            Text("In this practice, follow the highlighted control to plan your trip.")
        }
    }

    private var tabs: some View {
        HStack(spacing: 12) {
            ForEach(TripPlannerTab.allCases, id: \.self) { tab in
                Button { tappedTab = tab } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol).font(.body)
                        Text(tab.label)
                            .font(.body.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .minimumTapTarget()
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(tab == selected ? Color.accentColor : Color.secondary)
                .accessibilityAddTraits(tab == selected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 8)
    }
}
