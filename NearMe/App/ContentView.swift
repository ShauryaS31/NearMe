// Adapted from a prior prototype, used with permission.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.route {
            case .welcome:
                WelcomeView()
            case .goodMorning:
                GoodMorningView()
            case .howItWorks:
                HowItWorksView()
            case .session:
                SessionContainerView(userName: coordinator.userName)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.route)
        // The practice session follows system appearance. Preserve the
        // existing onboarding appearance until its palette is updated.
        .preferredColorScheme(coordinator.route == .session ? nil : .light)
    }
}

#Preview {
    ContentView().environmentObject(AppCoordinator())
}
