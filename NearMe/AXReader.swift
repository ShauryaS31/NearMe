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

    var errorDescription: String? {
        switch self {
        case .noFocusedWindow: "No focused window was readable in the target app. Check Accessibility permission and select its window."
        case .timedOut: "Accessibility read exceeded the 300 ms budget. Try again with the target window visible."
        }
    }
}

enum AXReader {
    static func read(processID: pid_t) async throws -> AXSnapshot {
        // Only Sendable value snapshots leave the worker. AX references remain on that worker.
        let (stream, continuation) = AsyncStream<Result<AXSnapshot, AXReadError>>.makeStream()
        let worker = Task.detached(priority: .userInitiated) {
            let result = AXTraversal().read(processID: processID)
            continuation.yield(result)
            continuation.finish()
        }
        let timeout = Task.detached {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
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
    private let start = ContinuousClock.now
    private var visitedNodes = 0
    private var truncated = false
    private var elements: [ScreenElement] = []
    private let roles: Set<String> = [
        "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuItem",
        "AXRow", "AXCell", "AXLink", "AXTab", "AXTextField", "AXSlider"
    ]

    private var remainingSeconds: Double {
        0.300 - milliseconds(start.duration(to: .now)) / 1_000
    }

    func read(processID: pid_t) -> Result<AXSnapshot, AXReadError> {
        let app = AXUIElementCreateApplication(processID)
        guard let rawWindow = attribute(app, kAXFocusedWindowAttribute),
              CFGetTypeID(rawWindow) == AXUIElementGetTypeID() else {
            return .failure(remainingSeconds <= 0 ? .timedOut : .noFocusedWindow)
        }
        let window = unsafeBitCast(rawWindow, to: AXUIElement.self)
        let title = string(window, kAXTitleAttribute)
        walk(window, depth: 0, parents: [], insideRow: false, parentEnabled: true)
        return .success(AXSnapshot(windowTitle: title, list: ElementList(elements),
                                   visitedNodes: visitedNodes, wasTruncated: truncated,
                                   milliseconds: milliseconds(start.duration(to: .now))))
    }

    private func prepare(_ element: AXUIElement) -> Bool {
        let remaining = remainingSeconds
        guard remaining > 0, !Task.isCancelled else {
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
        if status == .cannotComplete { truncated = true }
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

    private func walk(_ element: AXUIElement, depth: Int, parents: [String], insideRow: Bool,
                      parentEnabled: Bool, knownRole: String? = nil) {
        guard depth <= 25, visitedNodes < 400, prepare(element) else {
            truncated = true
            return
        }
        visitedNodes += 1
        let role = knownRole ?? string(element, kAXRoleAttribute)
        let subrole = string(element, kAXSubroleAttribute)
        // Secure controls and their descendants never enter the snapshot. AXValue is never queried.
        guard role != "AXSecureTextField", subrole != "AXSecureTextField" else { return }
        let title = string(element, kAXTitleAttribute)
        let label = title.isEmpty ? string(element, kAXDescriptionAttribute) : title
        let localEnabled = attribute(element, kAXEnabledAttribute) as? Bool
        let enabled = parentEnabled && (localEnabled ?? true)
        if roles.contains(role) || (role == "AXStaticText" && insideRow) {
            if let rect = frame(element) {
                // Unknown enabled state is not safe for a proposed actionable control.
                elements.append(ScreenElement(role: role, label: label, frame: rect,
                                              isEnabled: enabled && (localEnabled ?? (role == "AXStaticText")),
                                              breadcrumb: parents.suffix(3).joined(separator: " > ")))
            }
        }
        guard depth < 25, visitedNodes < 400 else {
            truncated = true
            return
        }
        guard prepare(element) else { return }
        var count: CFIndex = 0
        guard AXUIElementGetAttributeValueCount(element, kAXChildrenAttribute as CFString, &count) == .success,
              count > 0, prepare(element) else { return }
        let limit = min(count, 400 - visitedNodes)
        if limit < count { truncated = true }
        var rawChildren: CFArray?
        guard AXUIElementCopyAttributeValues(element, kAXChildrenAttribute as CFString, 0, limit, &rawChildren) == .success,
              let children = rawChildren as? [AXUIElement] else { return }
        let ancestry = label.isEmpty ? parents : Array((parents + [label]).suffix(3))
        // Visit the window's content containers before its toolbar/window buttons. Within
        // those containers keep native depth-first order (including sidebar/main content).
        // ElementList itself never reorders the resulting traversal when applying its cap.
        var ordered: [(element: AXUIElement, role: String?)] = children.map { ($0, nil) }
        if depth == 0 {
            let contentRoles: Set<String> = ["AXSplitGroup", "AXScrollArea", "AXOutline", "AXTable", "AXList", "AXGroup"]
            var preferred: [(element: AXUIElement, role: String?)] = []
            var other: [(element: AXUIElement, role: String?)] = []
            for child in children {
                guard remainingSeconds > 0, !Task.isCancelled else { truncated = true; break }
                let childRole = string(child, kAXRoleAttribute)
                if contentRoles.contains(childRole) { preferred.append((child, childRole)) }
                else { other.append((child, childRole)) }
            }
            ordered = preferred + other
        }
        for child in ordered {
            guard visitedNodes < 400, remainingSeconds > 0, !Task.isCancelled else {
                truncated = true
                break
            }
            walk(child.element, depth: depth + 1, parents: ancestry,
                 insideRow: insideRow || role == "AXRow", parentEnabled: enabled, knownRole: child.role)
        }
    }
}

func milliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1_000_000_000_000_000
}
