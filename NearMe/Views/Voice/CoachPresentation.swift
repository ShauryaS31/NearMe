import Foundation

nonisolated enum CoachPresentationKind: Equatable, Sendable {
    case homeReply, coachCard
}

struct CoachAppLink {
    let app: String
    let url: URL
}

/// Read-only decisions shared by Home, the coach card and presentation tests.
enum CoachPresentation {
    static func kind(for session: CoachSession?) -> CoachPresentationKind {
        guard let session else { return .homeReply }
        if session.guide != nil { return .coachCard }
        let currentText = session.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentText != CoachText.generalFallback else { return .homeReply }
        let realSteps: [String] = session.generalSteps.filter {
            let text = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !text.isEmpty && text != CoachText.generalFallback
        }
        return realSteps.isEmpty ? .homeReply : .coachCard
    }

    static func showsCoachCard(session: CoachSession?, error: String?) -> Bool {
        error == nil && kind(for: session) == .coachCard
    }

    static func reply(session: CoachSession?, error: String?) -> String? {
        if let error { return error }
        guard let session, kind(for: session) == .homeReply else { return nil }
        return session.text.isEmpty ? CoachText.generalFallback : session.text
    }

    static func appLaunch(for session: CoachSession) -> CoachAppLink? {
        guard let guide = session.guide, let url = CoachAppLaunch.url(for: guide) else { return nil }
        return CoachAppLink(app: guide.app, url: url)
    }
}
