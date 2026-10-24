import Foundation

/// The entire persisted payload. Never add requests, recipients or rewritten text.
nonisolated struct CoachProgress: Codable, Equatable, Sendable {
    let guideID: String
    var stepIndex: Int
    let sessionID: UUID
    var revision: Int
}

@MainActor
protocol CoachProgressStoring {
    func load() -> CoachProgress?
    func save(_ progress: CoachProgress)
    func clear()
}

@MainActor
final class CoachProgressStore: CoachProgressStoring {
    static let progressKey = "coach.progress"
    static let guideKey = "coach.guideID"
    static let stepKey = "coach.stepIndex"
    static let didChange = Notification.Name("NearMe.coachProgressChanged")
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) { self.defaults = defaults ?? .standard }

    func load() -> CoachProgress? {
        if let data = defaults.data(forKey: Self.progressKey) {
            guard let progress = try? JSONDecoder().decode(CoachProgress.self, from: data),
                  progress.stepIndex >= 0, progress.revision >= 0, progress.revision < Int.max else { return nil }
            return progress
        }
        // Upgrade the P07 record once, retaining its saved step.
        guard let guideID = defaults.string(forKey: Self.guideKey),
              let step = defaults.object(forKey: Self.stepKey) as? Int, step >= 0 else { return nil }
        let progress = CoachProgress(guideID: guideID, stepIndex: step, sessionID: UUID(), revision: 0)
        save(progress)
        return progress
    }

    func save(_ progress: CoachProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        // One defaults value prevents separately written fields getting out of sync.
        defaults.set(data, forKey: Self.progressKey)
        removeLegacyKeys()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    func clear() {
        defaults.removeObject(forKey: Self.progressKey)
        removeLegacyKeys()
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    private func removeLegacyKeys() {
        defaults.removeObject(forKey: Self.guideKey)
        defaults.removeObject(forKey: Self.stepKey)
    }
}
