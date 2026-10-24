// Adapted from a prior prototype, used with permission.

import Foundation

nonisolated struct ScreenSnapshot: Codable, Equatable, Sendable {
    let timestamp: TimeInterval
    let lines: [Line]

    nonisolated struct Line: Codable, Equatable, Sendable {
        let text: String
        let box: Box
    }

    /// Normalised coordinates, with the origin at the top left after orientation.
    nonisolated struct Box: Codable, Equatable, Sendable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        var clamped: Box? {
            guard [x, y, width, height].allSatisfy({ $0.isFinite }), width >= 0, height >= 0 else { return nil }
            let originInBounds: Bool = (0...1).contains(x) && (0...1).contains(y)
            if originInBounds, x + width <= 1, y + height <= 1 { return self }
            let left = min(1, max(0, x))
            let top = min(1, max(0, y))
            let right = min(1, max(left, x + width))
            let bottom = min(1, max(top, y + height))
            return Box(x: left, y: top, width: right - left, height: bottom - top)
        }

        var isValid: Bool {
            let values = [x, y, width, height]
            return values.allSatisfy { $0.isFinite && (0...1).contains($0) }
                && x + width <= 1.000001 && y + height <= 1.000001
        }

        var position: String {
            let vertical = y + height / 2 < 0.33 ? "top" : (y + height / 2 > 0.67 ? "bottom" : "middle")
            let horizontal = x + width / 2 < 0.33 ? "left" : (x + width / 2 > 0.67 ? "right" : "centre")
            return "\(vertical) \(horizontal)"
        }
    }

    func age(at now: TimeInterval) -> TimeInterval? {
        let age = now - timestamp
        return timestamp.isFinite && age.isFinite && age >= 0 ? age : nil
    }

    func isFresh(at now: TimeInterval) -> Bool {
        guard let age = age(at: now) else { return false }
        return age <= SharedScreenBridge.staleAfter
    }

    var textSet: Set<String> { Set(lines.map(\.text)) }
}

/// Conservative heuristics, not a guarantee that OCR can recognise every secret.
/// Filter full lines BEFORE truncation, in reading order, including the next line
/// after a password/passcode label even when that value contains only letters.
nonisolated enum ScreenSecretFilter {
    private static let patterns = [
        #"(?i)[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
        #"(?<!\d)(?:\d[ \-]?){12,18}\d(?!\d)"#,
        #"(?<!\w)\+?\d[\d ()\-]{5,}\d(?!\w)"#,
        #"(?i)(?<!\S)(?=\S*[A-Z])(?=\S*\d)\S{8,}(?!\S)"#
    ]
    private static let expressions = patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    private static let digits = try? NSRegularExpression(pattern: #"(?<!\d)\d{4,8}(?!\d)"#)
    private static let codeLabel = try? NSRegularExpression(pattern: #"(?i)\b(pin|code|otp|verification)\b"#)

    static func filtered(_ lines: [ScreenSnapshot.Line]) -> [ScreenSnapshot.Line] {
        let ordered: [ScreenSnapshot.Line] = lines.sorted {
            if $0.box.y != $1.box.y { return $0.box.y < $1.box.y }
            return $0.box.x < $1.box.x
        }
        var hideNext = false
        var result: [ScreenSnapshot.Line] = []
        for line in ordered {
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let isLabel = text.localizedCaseInsensitiveContains("password")
                || text.localizedCaseInsensitiveContains("passcode")
            let hidden = hideNext || isLabel || looksSecret(text)
            hideNext = isLabel
            guard !hidden, !text.isEmpty, let box = line.box.clamped else { continue }
            let singleLine = text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
            let bounded = String(singleLine.prefix(80))
            guard bounded.utf8.count <= 640 else { continue }
            result.append(ScreenSnapshot.Line(text: bounded, box: box))
            if result.count == 60 { break }
        }
        return result
    }

    static func looksSecret(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        let hasDigits = digits?.firstMatch(in: text, range: range) != nil
        let isCode = codeLabel?.firstMatch(in: text, range: range) != nil
        let letters = text.filter(\.isLetter).count
        if hasDigits && (letters < 3 || isCode) { return true }
        return expressions.contains { $0.firstMatch(in: text, range: range) != nil }
    }
}

/// Foundation-only; shared by the app and extension. No image transport.
nonisolated enum SharedScreenBridge {
    static let appGroupID = "group.au.nearme.shared"
    static let staleAfter: TimeInterval = 3
    static let maximumBytes = 65_536

    static var snapshotURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("screen-snapshot.json")
    }

    static func write(_ snapshot: ScreenSnapshot, to url: URL) throws {
        let safe = ScreenSnapshot(timestamp: snapshot.timestamp, lines: ScreenSecretFilter.filtered(snapshot.lines))
        let data = try JSONEncoder().encode(safe)
        guard data.count <= maximumBytes else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }

    static func read(from url: URL) -> ScreenSnapshot? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maximumBytes,
              let data = try? Data(contentsOf: url), data.count <= maximumBytes,
              let snapshot = try? JSONDecoder().decode(ScreenSnapshot.self, from: data),
              snapshot.timestamp.isFinite, snapshot.lines.count <= 60,
              snapshot.lines.allSatisfy({ $0.box.isValid && $0.text.count <= 80 && $0.text.utf8.count <= 640 })
        else { return nil }
        return snapshot
    }

    static func delete(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

/// Called under the extension's processing lock, also exercised without ReplayKit.
nonisolated final class ScreenSnapshotWriter {
    private let url: URL
    private var active = false
    private var lastFilteredLines: [ScreenSnapshot.Line] = []

    init(url: URL) { self.url = url }

    func start() throws {
        try SharedScreenBridge.delete(at: url)
        let legacy = url.deletingLastPathComponent().appendingPathComponent("screen-heartbeat.json")
        try SharedScreenBridge.delete(at: legacy)
        active = true
        lastFilteredLines = []
    }

    func write(_ snapshot: ScreenSnapshot) throws {
        guard active else { return }
        lastFilteredLines = ScreenSecretFilter.filtered(snapshot.lines)
        try refresh(at: snapshot.timestamp)
    }

    /// The caller serialises this heartbeat with OCR and stop. Only words are retained.
    func refresh(at timestamp: TimeInterval) throws {
        guard active else { return }
        try SharedScreenBridge.write(ScreenSnapshot(timestamp: timestamp, lines: lastFilteredLines), to: url)
    }

    func recognitionFailed(at timestamp: TimeInterval) throws {
        lastFilteredLines = []
        try refresh(at: timestamp)
    }

    func stop() throws {
        active = false
        lastFilteredLines = []
        try SharedScreenBridge.delete(at: url)
    }
}
