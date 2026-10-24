// Adapted from a prior prototype, used with permission.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch coordinator.route {
            case .welcome, .goodMorning:
                WelcomeView()
            case .howItWorks:
                HowItWorksView()
            case .session:
                SessionContainerView(userName: coordinator.userName)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: coordinator.route)
    }
}

#if DEBUG
#Preview {
    ContentView().environmentObject(AppCoordinator())
}
#endif
