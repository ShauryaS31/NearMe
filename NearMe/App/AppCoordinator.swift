// Adapted from a prior prototype, used with permission.

import SwiftUI
import Combine
import Foundation

nonisolated struct CoachURLRequest: Equatable {
    let id = UUID()
    let url: URL
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var route: AppRoute = .welcome
    @Published var userName: String = "Friend"
    @Published var pendingCoachURL: CoachURLRequest?

    init(progressStore: (any CoachProgressStoring)? = nil, guides: [CoachActivityGuide]? = nil) {
        let store = progressStore ?? CoachProgressStore()
        let library = guides ?? CoachActivityGuide.bundled()
        if let progress = store.load(), let guide = library.first(where: { $0.id == progress.guideID }),
           guide.steps.indices.contains(progress.stepIndex) {
            route = .session
        }
    }

    func handleOpenURL(_ url: URL) {
        guard CoachDeepLink.parse(url, savedSessionID: nil) != .ignored else { return }
        pendingCoachURL = CoachURLRequest(url: url)
        route = .session
    }

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
