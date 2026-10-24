// Adapted from a prior prototype, used with permission.

import Foundation

enum SharedScreenBridge {
    static let appGroupID = "group.com.nearme.shared"
    private static let newFrameNotificationName = "com.nearme.screenguidance.newframe" as CFString

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// Where the broadcast extension drops the most recent frame as a JPEG.
    /// A single overwritten file (rather than a queue) is intentional —
    /// NearMe only ever needs to react to "what does the screen look like
    /// right now", not process every frame.
    static var latestFrameURL: URL? {
        containerURL?.appendingPathComponent("latest_frame.jpg")
    }

    /// Called by the broadcast extension after writing a new frame.
    static func notifyNewFrameAvailable() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(newFrameNotificationName),
            nil, nil, true
        )
    }

    /// Called by the main app to be told whenever a new frame lands.
    /// Returns a token — keep it alive for as long as you want to keep
    /// observing; deinit-ing it (or calling `stopObservingNewFrames`) removes
    /// the observer.
    static func observeNewFrames(_ handler: @escaping () -> Void) -> DarwinNotificationToken {
        DarwinNotificationToken(name: newFrameNotificationName, handler: handler)
    }
}

/// Thin, safe wrapper around CFNotificationCenter's C-callback-based Darwin
/// notification API (which has no native closure support) so call sites can
/// use an ordinary Swift closure.
final class DarwinNotificationToken {
    private let name: CFString
    private let handler: () -> Void

    fileprivate init(name: CFString, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observerPointer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(center, observerPointer, { _, observer, _, _, _ in
            guard let observer else { return }
            let token = Unmanaged<DarwinNotificationToken>.fromOpaque(observer).takeUnretainedValue()
            token.handler()
        }, name, nil, .deliverImmediately)
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observerPointer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(center, observerPointer, CFNotificationName(name), nil)
    }
}
