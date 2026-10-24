import Foundation
import UIKit

@MainActor
protocol CoachAppOpening {
    func canOpen(_ url: URL) -> Bool
    func open(_ url: URL) async -> Bool
}

@MainActor
struct SystemCoachAppOpener: CoachAppOpening {
    func canOpen(_ url: URL) -> Bool { UIApplication.shared.canOpenURL(url) }

    func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }
}

enum CoachAppLaunch {
    static func url(for guide: HelpGuide) -> URL? {
        // Only the documented schemes already accepted by the guide library.
        guard guide.steps.count > 1, let first = guide.steps.first,
              first.instruction == "Open \"\(guide.app)\".",
              first.uiLabelHint == guide.app,
              let scheme = guide.appURLScheme else { return nil }
        switch (guide.app, scheme) {
        case ("WhatsApp", "whatsapp://"), ("Messages", "sms:"), ("YouTube", "youtube://"):
            return URL(string: scheme)
        default:
            return nil
        }
    }
}
