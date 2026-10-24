// Adapted from a prior prototype, used with permission.

import SwiftUI
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    static let placeholderName = "Friend"
    @Published var route: AppRoute = .welcome
    @Published var userName: String = AppCoordinator.placeholderName

    func advanceFromWelcome() {
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
