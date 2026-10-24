// Adapted from a prior prototype, used with permission.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            switch AppEntryPresentation.route(coordinator.route, hasCompletedOnboarding: hasCompletedOnboarding) {
            case .welcome, .goodMorning:
                WelcomeView()
            case .howItWorks:
                HowItWorksView()
            case .session:
                SessionContainerView(userName: coordinator.userName)
            }
        }
        .tint(TTColor.accent)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: coordinator.route)
        .onChange(of: coordinator.route, initial: true) { _, route in
            if route == .session { hasCompletedOnboarding = true }
        }
    }
}

/// Resolve launch navigation in the UI without changing coordinator/deep-link logic.
enum AppEntryPresentation {
    static func route(_ route: AppRoute, hasCompletedOnboarding: Bool) -> AppRoute {
        if hasCompletedOnboarding && (route == .welcome || route == .goodMorning) { return .session }
        return route
    }
}

#if DEBUG
#Preview {
    ContentView().environmentObject(AppCoordinator())
}
#endif
