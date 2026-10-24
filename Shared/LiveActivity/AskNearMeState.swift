import ActivityKit
import Foundation
import WidgetKit

nonisolated enum AskPhase: String, Codable, Sendable {
    case setup, ready, starting, listening, finishing, answering, checking, paused, ending, needsApp, stopped, failed, statusUnavailable

    var title: String {
        switch self {
        case .setup: return "Set up NearMe"
        case .ready: return "Ask NearMe"
        case .starting: return "Getting ready"
        case .listening: return "Listening"
        case .finishing: return "Finishing"
        case .answering: return "Answering"
        case .checking: return "Checking in"
        case .paused: return "Paused for audio"
        case .ending: return "Stopping"
        case .needsApp: return "Continue in NearMe"
        case .stopped: return "Stopped"
        case .failed: return "Please try again"
        case .statusUnavailable: return "Check NearMe"
        }
    }
}

/// Only status and timing cross the process boundary. Never speech or user context.
nonisolated struct AskWidgetState: Codable, Equatable, Sendable {
    var phase: AskPhase
    var sessionID: UUID?
    var startedAt: Date?
    var expiresAt: Date?
    var continueInApp = false

    func current(at date: Date) -> Self {
        guard let expiresAt, date >= expiresAt else { return self }
        // A delayed widget reload cannot prove that audio stopped. Keep an explicit
        // Stop/recovery affordance, without asserting either Listening or Stopped.
        return Self(phase: .statusUnavailable, sessionID: sessionID, continueInApp: true)
    }
}

nonisolated enum AskWidgetStore {
    static let kind = "AskNearMe"
    static let onboardingKey = "askNearMe.onboardingComplete"
    static let setupKey = "askNearMe.setupComplete"
    private static let stateKey = "askNearMe.state"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.au.nearme.shared") }

    static func read(at date: Date = Date()) -> AskWidgetState {
        guard let data = defaults?.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(AskWidgetState.self, from: data) else {
            return AskWidgetState(phase: .setup)
        }
        return state.current(at: date)
    }

    static func write(_ state: AskWidgetState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults?.set(data, forKey: stateKey)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    static func isSetupURL(_ url: URL) -> Bool {
        url.scheme == "nearme" && url.host == "ask" && (url.path.isEmpty || url.path == "/")
            && url.query == nil && url.fragment == nil && url.user == nil && url.port == nil
    }

    static func isSessionURL(_ url: URL) -> Bool {
        url.scheme == "nearme" && url.host == "ask" && url.path == "/continue"
            && url.query == nil && url.fragment == nil && url.user == nil && url.port == nil
    }
}

nonisolated struct AskActivityAttributes: ActivityAttributes {
    let sessionID: UUID
    nonisolated struct ContentState: Codable, Hashable {
        let phase: AskPhase
        let startedAt: Date?
        let expiresAt: Date
        var continueInApp = false
    }
}
