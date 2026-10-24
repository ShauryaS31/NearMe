// Adapted from a prior prototype, used with permission.

import Foundation
import CoreGraphics

struct DetectedScreenElement {
    let text: String
    /// Normalized (0...1) bounding box in the captured frame, matching
    /// Vision's coordinate convention (origin bottom-left).
    let boundingBox: CGRect
}

@MainActor
protocol ScreenGuidanceService: AnyObject {
    /// Reserved for screen guidance. The P13 spike only shares a heartbeat;
    /// it does not implement text detection or watch a frame feed.
    func startWatching()
    func stopWatching()

    /// Tell the service what on-screen text/labels currently matter (e.g.
    /// ["Journey Planner"] right after opening trip planner). It will call
    /// `onElementDetected` once a frame's OCR result contains a close match.
    func lookFor(labels: [String])

    var onElementDetected: ((DetectedScreenElement) -> Void)? { get set }
}
