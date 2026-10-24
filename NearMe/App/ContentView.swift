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
                SessionContainerView(userName: coordinator.userName) {
                    coordinator.restartOnboarding()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.route)
        // A fixed light appearance keeps the brand's lavender palette
        // consistent regardless of the system Dark Mode setting. Dynamic
        // Type and screen-size adaptivity (the two things actually asked
        // for) are unaffected by this — see README for how to add a dark
        // variant later if desired.
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView().environmentObject(AppCoordinator())
}
