import Foundation

nonisolated enum CoachDeepLink: Equatable, Sendable {
    case coach(UUID)
    case home
    case ignored

    static func parse(_ url: URL, savedSessionID: UUID?) -> Self {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "nearme" else { return .ignored }
        if let host = parts.host, !host.isEmpty, host != "coach" { return .ignored }
        guard parts.host == "coach", parts.path.isEmpty, parts.fragment == nil,
              parts.user == nil, parts.password == nil, parts.port == nil,
              let items = parts.queryItems, items.count == 1, items[0].name == "session",
              let value = items[0].value, let id = UUID(uuidString: value), id == savedSessionID
        else { return .home }
        return .coach(id)
    }

    static func url(sessionID: UUID) -> URL? {
        var parts = URLComponents()
        parts.scheme = "nearme"
        parts.host = "coach"
        parts.queryItems = [URLQueryItem(name: "session", value: sessionID.uuidString)]
        return parts.url
    }
}
