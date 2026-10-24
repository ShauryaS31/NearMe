import AppKit
import NearMeCore
import Observation

struct TargetApp: Equatable, Sendable {
    let processID: pid_t
    let name: String
    let bundleID: String
}

@MainActor
@Observable
final class TargetAppTracker: NSObject {
    private(set) var app: TargetApp?

    override init() {
        super.init()
        if let frontmost = NSWorkspace.shared.frontmostApplication { remember(frontmost) }
        // Workspace activation notifications are delivered on the main thread. Selector-based
        // observers are weakly held and automatically unregistered when this object goes away.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
    }

    @objc private func didActivate(_ notification: Notification) {
        guard let runningApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        remember(runningApp)
    }

    private func remember(_ runningApp: NSRunningApplication) {
        guard runningApp.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        app = TargetApp(processID: runningApp.processIdentifier,
                        name: PrivacyFilter.sanitiseLabel(runningApp.localizedName ?? "Unknown app"),
                        bundleID: runningApp.bundleIdentifier ?? "")
    }
}
