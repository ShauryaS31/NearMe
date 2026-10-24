import ApplicationServices
import Foundation
import NearMeCore

struct AXSnapshot: Sendable {
    let windowTitle: String
    let list: ElementList
    let visitedNodes: Int
    let wasTruncated: Bool
    let milliseconds: Double
}

enum AXReadError: LocalizedError {
    case noFocusedWindow
    case timedOut
    case blocked(String)

    var errorDescription: String? {
        switch self {
        case .noFocusedWindow: "No focused window was readable in the target app. Check Accessibility permission and select its window."
        case .timedOut: "Accessibility read exceeded the 300 ms budget. Try again with the target window visible."
        case .blocked(let reason): "Blocked: \(reason)"
        }
    }
}

enum AXReader {
    static func read(processID: pid_t, bundleID: String) async throws -> AXSnapshot {
        // Bundle blocking needs no AX messages at all.
        if let reason = PrivacyFilter.blockReason(bundleID: bundleID, windowTitle: "") {
            throw AXReadError.blocked(reason)
        }
        let start = ContinuousClock.now
        // Only Sendable value snapshots leave the worker. AX references remain on that worker.
        let (stream, continuation) = AsyncStream<Result<AXSnapshot, AXReadError>>.makeStream()
        let worker = Task.detached(priority: .userInitiated) {
            let result = AXTraversal(start: start).read(processID: processID, bundleID: bundleID)
            continuation.yield(result)
            continuation.finish()
        }
        let timeout = Task.detached {
            do {
                try await Task.sleep(until: start.advanced(by: .milliseconds(300)), clock: .continuous)
            } catch { return }
            continuation.yield(.failure(.timedOut))
            continuation.finish()
            worker.cancel()
        }
        defer {
            worker.cancel()
            timeout.cancel()
            continuation.finish()
        }
        var iterator = stream.makeAsyncIterator()
        guard let result = await iterator.next() else { throw CancellationError() }
        try Task.checkCancellation()
        return try result.get()
    }
}

/// Synchronous, private to one detached task, with a deadline before every AX message.
private final class AXTraversal {
    private let start: ContinuousClock.Instant
    private var visitedNodes = 0
    private var truncated = false
    private var elements: [ScreenElement] = []
    private let roles: Set<String> = [
        "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuItem",
        "AXRow", "AXCell", "AXLink", "AXTab", "AXTextField", "AXSlider"
    ]

    init(start: ContinuousClock.Instant) {
        self.start = start
    }

    private var remainingSeconds: Double {
        // Leave 50 ms to return a partial snapshot before the shared-start watchdog fires.
        0.250 - milliseconds(start.duration(to: .now)) / 1_000
    }

    func read(processID: pid_t, bundleID: String) -> Result<AXSnapshot, AXReadError> {
        let app = AXUIElementCreateApplication(processID)
        guard let rawWindow = attribute(app, kAXFocusedWindowAttribute),
              CFGetTypeID(rawWindow) == AXUIElementGetTypeID() else {
            if remainingSeconds <= 0 { return .failure(.timedOut) }
            return .failure(.noFocusedWindow)
        }
        let window = unsafeBitCast(rawWindow, to: AXUIElement.self)
        // Fail closed if the title cannot be read. An explicitly empty title is allowed.
        guard let title = attribute(window, kAXTitleAttribute) as? String else {
            return .failure(truncated ? .timedOut : .noFocusedWindow)
        }
        if let reason = PrivacyFilter.blockReason(bundleID: bundleID, windowTitle: title) {
            return .failure(.blocked(reason))
        }
        walk(window, depth: 0, parentLabel: "", insideRow: false)
        return snapshot(windowTitle: title)
    }

    private func snapshot(windowTitle: String) -> Result<AXSnapshot, AXReadError> {
        .success(AXSnapshot(windowTitle: PrivacyFilter.sanitiseLabel(windowTitle),
                            list: ElementList(PrivacyFilter.sanitise(elements)),
                            visitedNodes: visitedNodes, wasTruncated: truncated,
                            milliseconds: milliseconds(start.duration(to: .now))))
    }

    private func prepare(_ element: AXUIElement) -> Bool {
        guard !Task.isCancelled else { return false }
        let remaining = remainingSeconds
        guard remaining > 0 else {
            truncated = true
            return false
        }
        // A hung target must not consume a default multi-second AX IPC timeout.
        AXUIElementSetMessagingTimeout(element, Float(min(remaining, 0.020)))
        return true
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        guard prepare(element) else { return nil }
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        if status == .cannotComplete, !Task.isCancelled { truncated = true }
        return status == .success ? value : nil
    }

    private func string(_ element: AXUIElement, _ name: String) -> String {
        (attribute(element, name) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func frame(_ element: AXUIElement) -> CGRect? {
        guard let rawPosition = attribute(element, kAXPositionAttribute),
              let rawSize = attribute(element, kAXSizeAttribute),
              CFGetTypeID(rawPosition) == AXValueGetTypeID(),
              CFGetTypeID(rawSize) == AXValueGetTypeID() else { return nil }
        let position = unsafeBitCast(rawPosition, to: AXValue.self)
        let size = unsafeBitCast(rawSize, to: AXValue.self)
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize,
              AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions),
              point.x.isFinite, point.y.isFinite, dimensions.width.isFinite, dimensions.height.isFinite,
              dimensions.width > 0, dimensions.height > 0 else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    private func visit(_ element: AXUIElement, depth: Int) -> Bool {
        guard !Task.isCancelled else { return false }
        guard depth <= 25, visitedNodes < 400 else {
            truncated = true
            return false
        }
        guard prepare(element) else { return false }
        visitedNodes += 1
        return true
    }

    private func visibleLabel(_ element: AXUIElement, role: String) -> String {
        // Only static text exposes AXValue as visible label text. Never query control values.
        if role == "AXStaticText" { return string(element, kAXValueAttribute) }
        let title = string(element, kAXTitleAttribute)
        return title.isEmpty ? string(element, kAXDescriptionAttribute) : title
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        guard !Task.isCancelled else { return [] }
        guard visitedNodes < 400 else { truncated = true; return [] }
        guard prepare(element) else { return [] }
        var count: CFIndex = 0
        let countStatus = AXUIElementGetAttributeValueCount(element, kAXChildrenAttribute as CFString, &count)
        if countStatus == .cannotComplete, !Task.isCancelled { truncated = true }
        guard countStatus == .success, count > 0, prepare(element) else { return [] }
        let limit = min(count, 400 - visitedNodes)
        if limit < count { truncated = true }
        var rawChildren: CFArray?
        let childrenStatus = AXUIElementCopyAttributeValues(element, kAXChildrenAttribute as CFString, 0, limit, &rawChildren)
        if childrenStatus == .cannotComplete, !Task.isCancelled { truncated = true }
        guard childrenStatus == .success else { return [] }
        return rawChildren as? [AXUIElement] ?? []
    }

    private func firstStaticTextLabel(in element: AXUIElement, depth: Int, levelsRemaining: Int) -> String? {
        guard levelsRemaining > 0 else { return nil }
        for child in children(of: element) {
            // Label probes share both the traversal's message deadline and its node budget.
            guard visit(child, depth: depth + 1) else { return nil }
            let role = string(child, kAXRoleAttribute)
            let subrole = string(child, kAXSubroleAttribute)
            guard role != "AXSecureTextField", subrole != "AXSecureTextField" else { continue }
            if role == "AXStaticText" { return visibleLabel(child, role: role) }
            if let label = firstStaticTextLabel(in: child, depth: depth + 1, levelsRemaining: levelsRemaining - 1) {
                return label
            }
        }
        return nil
    }

    private func walk(_ element: AXUIElement, depth: Int, parentLabel: String, insideRow: Bool,
                      knownRole: String? = nil) {
        guard visit(element, depth: depth) else { return }
        let role = knownRole ?? string(element, kAXRoleAttribute)
        let subrole = string(element, kAXSubroleAttribute)
        // Secure controls and their descendants never enter the snapshot or label lookup.
        guard role != "AXSecureTextField", subrole != "AXSecureTextField" else { return }
        var label = visibleLabel(element, role: role)
        if label.isEmpty, role == "AXRow" || role == "AXCell" {
            label = firstStaticTextLabel(in: element, depth: depth, levelsRemaining: min(3, 25 - depth)) ?? ""
        }
        let enabled = (attribute(element, kAXEnabledAttribute) as? Bool) ?? true
        if roles.contains(role) || (role == "AXStaticText" && insideRow) {
            if let rect = frame(element) {
                elements.append(ScreenElement(role: role, label: label, frame: rect,
                                              isEnabled: enabled, breadcrumb: parentLabel))
            }
        }
        guard !Task.isCancelled else { return }
        guard depth < 25, visitedNodes < 400 else {
            truncated = true
            return
        }
        let children = self.children(of: element)
        let ancestry = label.isEmpty ? parentLabel : label
        // Visit the window's content containers before its toolbar/window buttons. Within
        // those containers keep native depth-first order (including sidebar/main content).
        // ElementList itself never reorders the resulting traversal when applying its cap.
        var ordered: [(element: AXUIElement, role: String?)] = children.map { ($0, nil) }
        if depth == 0 {
            let contentRoles: Set<String> = ["AXSplitGroup", "AXScrollArea", "AXOutline", "AXTable", "AXList", "AXGroup"]
            var preferred: [(element: AXUIElement, role: String?)] = []
            var other: [(element: AXUIElement, role: String?)] = []
            for child in children {
                guard prepare(child) else { break }
                let childRole = string(child, kAXRoleAttribute)
                if contentRoles.contains(childRole) { preferred.append((child, childRole)) }
                else { other.append((child, childRole)) }
            }
            ordered = preferred + other
        }
        for child in ordered {
            guard !Task.isCancelled else { break }
            guard visitedNodes < 400 else {
                truncated = true
                break
            }
            guard prepare(child.element) else { break }
            walk(child.element, depth: depth + 1, parentLabel: ancestry,
                 insideRow: insideRow || role == "AXRow", knownRole: child.role)
        }
    }
}

func milliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1_000_000_000_000_000
}
