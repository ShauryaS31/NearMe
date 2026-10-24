// Adapted from a prior prototype, used with permission.

import Foundation
import OSLog

enum BrainSource: String, Sendable {
    case onDeviceModel
    case onDeviceModelWithKeywordFill
    case keywordFallback
    case template

    var label: String {
        switch self {
        case .onDeviceModel: return "On-device model"
        case .onDeviceModelWithKeywordFill: return "On-device model + keyword fill"
        case .keywordFallback: return "Keyword fallback"
        case .template: return "Template"
        }
    }
}

struct BrainAnswer<Value: Sendable>: Sendable {
    let value: Value
    let source: BrainSource
    let latencyMilliseconds: Int?

    init(value: Value, source: BrainSource, latencyMilliseconds: Int? = nil) {
        self.value = value
        self.source = source
        self.latencyMilliseconds = latencyMilliseconds
    }
}

protocol TaskPlannerBrain: Sendable {
    var initialSource: BrainSource { get }
    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent>
    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?>
    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String>
    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String>
}

extension TaskPlannerBrain {
    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String> {
        BrainAnswer(value: PlannerTemplates.question(for: missing), source: .template)
    }

    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String> {
        BrainAnswer(value: PlannerTemplates.confirmation(for: intent), source: .template)
    }
}

enum PlannerDiagnostics {
    static let logger = Logger(subsystem: "au.nearme.ios", category: "planner")

    static func milliseconds(_ duration: Duration) -> Int {
        let parts = duration.components
        return Int(parts.seconds * 1_000 + parts.attoseconds / 1_000_000_000_000_000)
    }

    static func modelCall(_ kind: String, outcome: String, milliseconds: Int) {
        VoiceDiagnostics.logger.notice("Model call=\(kind, privacy: .public) outcome=\(outcome, privacy: .public) ms=\(milliseconds, privacy: .public)")
        logger.notice("Model call=\(kind, privacy: .public) outcome=\(outcome, privacy: .public) ms=\(milliseconds, privacy: .public)")
    }

    static func fallback(after error: Error, call: String) {
        let nsError = error as NSError
        logger.error("Model call=\(call, privacy: .public) failed type=\(String(reflecting: type(of: error)), privacy: .public) domain=\(nsError.domain, privacy: .private) code=\(nsError.code, privacy: .public) description=\(nsError.localizedDescription, privacy: .private); using keyword fallback")
    }
}

final class ResilientTaskPlannerBrain: TaskPlannerBrain, @unchecked Sendable {
    private let primary: TaskPlannerBrain
    private let fallback: TaskPlannerBrain
    var initialSource: BrainSource { primary.initialSource }

    init(primary: TaskPlannerBrain, fallback: TaskPlannerBrain) {
        self.primary = primary
        self.fallback = fallback
    }

    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        let answer: BrainAnswer<JourneyIntent>
        do {
            answer = try await primary.extractIntent(from: utterance)
        } catch {
            PlannerDiagnostics.fallback(after: error, call: "extractIntent")
            return try await fallback.extractIntent(from: utterance)
        }

        // Parse every sentence again, filling only absent model values.
        let keywords = try await fallback.extractIntent(from: utterance).value
        var intent = answer.value
        var didFill = false
        if intent.kind == .unknown, keywords.kind == .planJourney,
           keywords.origin != nil || keywords.destination != nil {
            intent.intent = .planJourney
            didFill = true
        }
        if intent.origin?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
           let origin = keywords.origin {
            intent.origin = origin
            didFill = true
        }
        if intent.destination?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
           let destination = keywords.destination {
            intent.destination = destination
            didFill = true
        }
        if intent.mode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
           let mode = keywords.mode {
            intent.mode = mode
            didFill = true
        }
        if didFill {
            PlannerDiagnostics.logger.debug("Model extraction supplemented by keyword fill")
        }
        return BrainAnswer(value: intent, source: didFill ? .onDeviceModelWithKeywordFill : answer.source,
                           latencyMilliseconds: answer.latencyMilliseconds)
    }

    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        let modelAnswer: BrainAnswer<String?>
        do {
            modelAnswer = try await primary.extractPlace(from: answer, for: slot)
        } catch {
            PlannerDiagnostics.fallback(after: error, call: "extractPlace")
            return try await fallback.extractPlace(from: answer, for: slot)
        }

        // The model can return a whole sentence rather than just the place.
        var place: String?
        if let modelPlace = modelAnswer.value {
            place = try await fallback.extractPlace(from: modelPlace, for: slot).value
        }
        if place == nil {
            place = try await fallback.extractPlace(from: answer, for: slot).value
        }
        let didFill = place != modelAnswer.value
        if didFill {
            PlannerDiagnostics.logger.debug("Model place extraction supplemented by keyword fill")
        }
        return BrainAnswer(value: place, source: didFill ? .onDeviceModelWithKeywordFill : modelAnswer.source,
                           latencyMilliseconds: modelAnswer.latencyMilliseconds)
    }


}

enum TaskPlannerBrainFactory {
    @MainActor static func makeDefault() -> TaskPlannerBrain {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelsBrain.isAvailable {
            return ResilientTaskPlannerBrain(primary: FoundationModelsBrain(), fallback: KeywordFallbackBrain())
        }
        #endif
        PlannerDiagnostics.logger.notice("On-device model unavailable; using keyword fallback")
        return KeywordFallbackBrain()
    }
}
