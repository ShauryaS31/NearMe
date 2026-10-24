import Foundation

nonisolated struct CoachSession: Sendable {
    let id = UUID()
    let guide: HelpGuide?
    let request: String
    let person: String?
    let generalSteps: [String]
    var stepIndex: Int
    var text: String
    var slower = false

    var count: Int { guide?.steps.count ?? generalSteps.count }
    var isGeneral: Bool { guide == nil }
    var needsScreenCheck: Bool { guide?.steps[stepIndex].verify == true }
}

@MainActor
final class CoachProgressStore {
    private let defaults: UserDefaults
    static let guideKey = "coach.guideID"
    static let stepKey = "coach.stepIndex"

    init(defaults: UserDefaults? = nil) { self.defaults = defaults ?? .standard }

    func save(_ session: CoachSession) {
        guard let guide = session.guide else { clear(); return }
        defaults.set(guide.id, forKey: Self.guideKey)
        defaults.set(session.stepIndex, forKey: Self.stepKey)
    }

    func restore(guides: [HelpGuide]) -> CoachSession? {
        guard let id = defaults.string(forKey: Self.guideKey),
              let index = defaults.object(forKey: Self.stepKey) as? Int,
              let guide = guides.first(where: { $0.id == id }), guide.steps.indices.contains(index) else {
            clear()
            return nil
        }
        return CoachSession(guide: guide, request: "", person: nil, generalSteps: [],
                            stepIndex: index, text: CoachText.fallback(step: guide.steps[index], person: nil))
    }

    func clear() {
        defaults.removeObject(forKey: Self.guideKey)
        defaults.removeObject(forKey: Self.stepKey)
    }
}
