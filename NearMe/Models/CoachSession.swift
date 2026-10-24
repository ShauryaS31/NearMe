import Foundation

nonisolated struct CoachSession: Sendable {
    var id = UUID()
    var revision = 0
    let guide: HelpGuide?
    let request: String
    let person: String?
    let generalSteps: [String]
    var stepIndex: Int
    var text: String
    var slower = false
    var song: String? = nil

    var count: Int { guide?.steps.count ?? generalSteps.count }
    var isGeneral: Bool { guide == nil }
    var needsScreenCheck: Bool { guide?.steps[stepIndex].verify == true }
}

@MainActor
extension CoachProgressStore {
    func save(_ session: CoachSession) {
        guard let guide = session.guide else { clear(); return }
        save(CoachProgress(guideID: guide.id, stepIndex: session.stepIndex,
                           sessionID: session.id, revision: session.revision))
    }

    func restore(guides: [HelpGuide]) -> CoachSession? {
        guard let progress = load(), let guide = guides.first(where: { $0.id == progress.guideID }),
              guide.steps.indices.contains(progress.stepIndex) else {
            clear()
            return nil
        }
        return CoachSession(id: progress.sessionID, revision: progress.revision, guide: guide,
                            request: "", person: nil, generalSteps: [], stepIndex: progress.stepIndex,
                            text: CoachText.fallback(step: guide.steps[progress.stepIndex], person: nil))
    }
}

nonisolated extension HelpGuide {
    var activityGuide: CoachActivityGuide {
        CoachActivityGuide(id: id, title: title,
                           steps: steps.map { CoachActivityGuide.Step(instruction: $0.instruction) })
    }
}
