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
    static let placeholderName = "Friend"
    @Published var route: AppRoute = .welcome
    @Published var userName: String = AppCoordinator.placeholderName
    @Published var pendingCoachURL: CoachURLRequest?
    @Published var showsWidgetSetup = false
    private var pendingWidgetSetup = false
    private let defaults: UserDefaults

    init(progressStore: (any CoachProgressStoring)? = nil, guides: [CoachActivityGuide]? = nil,
         defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? .standard
        // Preserve completion from the existing orb-home onboarding flow.
        if self.defaults.bool(forKey: "hasCompletedOnboarding") {
            self.defaults.set(true, forKey: AskWidgetStore.onboardingKey)
        }
        let store = progressStore ?? CoachProgressStore()
        let library = guides ?? CoachActivityGuide.bundled()
        if self.defaults.bool(forKey: AskWidgetStore.onboardingKey) { route = .session }
        if let progress = store.load(), let guide = library.first(where: { $0.id == progress.guideID }),
           guide.steps.indices.contains(progress.stepIndex) {
            route = .session
        }
    }

    func handleOpenURL(_ url: URL) {
        if AskWidgetStore.isSetupURL(url) || AskWidgetStore.isSessionURL(url) {
            if defaults.bool(forKey: AskWidgetStore.onboardingKey) {
                route = .session
                showsWidgetSetup = AskWidgetStore.isSetupURL(url)
            } else {
                pendingWidgetSetup = AskWidgetStore.isSetupURL(url)
                route = .welcome
            }
            return
        }
        guard CoachDeepLink.parse(url, savedSessionID: nil) != .ignored else { return }
        pendingCoachURL = CoachURLRequest(url: url)
        route = .session
    }

    func advanceFromWelcome() {
        route = .howItWorks
    }

    func advanceFromHowItWorks() {
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(true, forKey: AskWidgetStore.onboardingKey)
        route = .session
        if pendingWidgetSetup { pendingWidgetSetup = false; showsWidgetSetup = true }
    }

    /// Explicit onboarding restart. Ending guidance now returns to the help home.
    func restartOnboarding() {
        defaults.set(false, forKey: "hasCompletedOnboarding")
        defaults.set(false, forKey: AskWidgetStore.onboardingKey)
        defaults.set(false, forKey: AskWidgetStore.setupKey)
        pendingWidgetSetup = false
        showsWidgetSetup = false
        AskWidgetStore.write(AskWidgetState(phase: .setup))
        route = .welcome
    }
}
