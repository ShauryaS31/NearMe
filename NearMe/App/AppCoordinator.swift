// Adapted from a prior prototype, used with permission.

import SwiftUI
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var route: AppRoute = .welcome
    @Published var userName: String = "Friend"

    func advanceFromWelcome() {
        route = .goodMorning
    }

    func advanceFromGoodMorning() {
        route = .howItWorks
    }

    func advanceFromHowItWorks() {
        route = .session
    }

    /// Also used as "end session"'s destination — SessionContainerView calls
    /// this once the engine has torn down, since there's no dedicated
    /// "session ended" screen in the mockups.
    func restartOnboarding() {
        route = .welcome
    }
}
