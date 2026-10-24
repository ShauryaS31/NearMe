// Adapted from a prior prototype, used with permission.

import Foundation

nonisolated struct ScreenBroadcastHeartbeat: Codable, Equatable, Sendable {
    /// Seconds since the Unix epoch, shared by both processes.
    let timestamp: TimeInterval
    let frameCount: Int
}

/// Foundation-only so this file can also compile with extension-safe APIs.
nonisolated enum SharedScreenBridge {
    static let appGroupID = "group.au.nearme.shared"
    static let staleAfter: TimeInterval = 3

    static var heartbeatURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("screen-heartbeat.json")
    }

    static func write(_ heartbeat: ScreenBroadcastHeartbeat, to url: URL) throws {
        let data = try JSONEncoder().encode(heartbeat)
        try data.write(to: url, options: .atomic)
    }

    static func read(from url: URL) -> ScreenBroadcastHeartbeat? {
        guard let data = try? Data(contentsOf: url), data.count <= 1_024 else { return nil }
        return try? JSONDecoder().decode(ScreenBroadcastHeartbeat.self, from: data)
    }

    static func debugLine(heartbeat: ScreenBroadcastHeartbeat?, now: Date) -> String {
        guard let heartbeat, heartbeat.frameCount >= 0, heartbeat.timestamp.isFinite else {
            return "Screen: off"
        }
        let age = now.timeIntervalSince1970 - heartbeat.timestamp
        guard age.isFinite, age >= 0, age <= staleAfter else { return "Screen: off" }
        return "Screen: broadcast on, last update \(Int(age)) s ago"
    }
}
