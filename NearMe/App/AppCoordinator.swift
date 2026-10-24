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

    /// Explicit onboarding restart. Ending guidance now returns to the help home.
    func restartOnboarding() {
        route = .welcome
    }
}
