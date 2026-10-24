import ActivityKit
import Foundation

nonisolated struct CoachActivityAttributes: ActivityAttributes, Sendable {
    let guideTitle: String
    let totalSteps: Int
    let sessionID: UUID

    nonisolated struct ContentState: Codable, Hashable, Sendable {
        let stepNumber: Int
        let instruction: String
        let revision: Int
        let isComplete: Bool

        func progressText(totalSteps: Int) -> String { "\(stepNumber)/\(totalSteps)" }
    }
}

/// Decodes only editorial guide content from the app bundle, never a model rewrite.
nonisolated struct CoachActivityGuide: Decodable, Sendable {
    let id: String
    let title: String
    let steps: [Step]

    nonisolated struct Step: Decodable, Sendable {
        let instruction: String
    }

    static func bundled() -> [CoachActivityGuide] {
        guard let directory = Bundle.main.url(forResource: "guides", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }
        return files.filter { $0.pathExtension == "json" }.compactMap { file in
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? JSONDecoder().decode(CoachActivityGuide.self, from: data)
        }
    }
}

nonisolated struct CoachActivitySnapshot: Sendable {
    let attributes: CoachActivityAttributes
    let state: CoachActivityAttributes.ContentState

    static func build(progress: CoachProgress, guide: CoachActivityGuide, completed: Bool = false) -> Self? {
        guard guide.id == progress.guideID, guide.steps.indices.contains(progress.stepIndex) else { return nil }
        let instruction = completed ? "Done, well done" : guide.steps[progress.stepIndex].instruction
        // Bound characters AND UTF-8 bytes (a single grapheme may contain many scalars).
        let title = bounded(guide.title)
        let state = CoachActivityAttributes.ContentState(stepNumber: progress.stepIndex + 1,
            instruction: bounded(instruction), revision: progress.revision, isComplete: completed)
        let attributes = CoachActivityAttributes(guideTitle: title, totalSteps: guide.steps.count,
                                                sessionID: progress.sessionID)
        guard let attributesData = try? JSONEncoder().encode(attributes),
              let stateData = try? JSONEncoder().encode(state),
              attributesData.count + stateData.count < 4_096 else { return nil }
        return Self(attributes: attributes, state: state)
    }

    private static func bounded(_ text: String) -> String {
        var result = ""
        for character in text.prefix(120) {
            let next = String(character)
            guard result.utf8.count + next.utf8.count <= 600 else { break }
            result.append(character)
        }
        return result
    }
}
