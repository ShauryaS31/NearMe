// Adapted from a prior prototype, used with permission.

import UIKit

struct PTVLauncher {
    /// Best-guess Universal Link into PTV's Journey Planner. Replace once confirmed.
    private static let universalLinkJourneyPlanner = URL(string: "https://www.ptv.vic.gov.au/journey")!
    /// Best-guess custom URL scheme fallback. Replace once confirmed.
    private static let customSchemeJourneyPlanner = URL(string: "ptv://journeyplanner")!
    private static let appStoreURL = URL(string: "https://apps.apple.com/au/app/ptv/id942711194")!

    enum LaunchResult {
        case openedApp
        case openedAppStore
        case failed
    }

    @discardableResult
    static func openJourneyPlanner() async -> LaunchResult {
        let application = UIApplication.shared

        if await application.canOpenURL(universalLinkJourneyPlanner),
           await application.open(universalLinkJourneyPlanner) {
            return .openedApp
        }

        if await application.canOpenURL(customSchemeJourneyPlanner),
           await application.open(customSchemeJourneyPlanner) {
            return .openedApp
        }

        if await application.open(appStoreURL) {
            return .openedAppStore
        }

        return .failed
    }
}

private extension UIApplication {
    func canOpenURL(_ url: URL) async -> Bool {
        await MainActor.run { self.canOpenURL(url) }
    }

    @discardableResult
    func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.open(url, options: [:]) { success in
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
