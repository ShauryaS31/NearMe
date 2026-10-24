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
    let fallbackReason: ModelFallbackReason?

    init(value: Value, source: BrainSource, latencyMilliseconds: Int? = nil,
         fallbackReason: ModelFallbackReason? = nil) {
        self.value = value
        self.source = source
        self.latencyMilliseconds = latencyMilliseconds
        self.fallbackReason = fallbackReason
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

    static func modelCall(_ kind: String, outcome: String, milliseconds: Int,
                          reason: ModelFallbackReason? = nil, error: Error? = nil,
                          candidates: [GuideCandidate]? = nil) {
        let availability: String
        if let reason, case .unavailable(let value) = reason { availability = value.rawValue }
        else { availability = "available" }
        let errorType = error.map { String(reflecting: type(of: $0)) } ?? "none"
        let errorCode = error.map { ($0 as NSError).code } ?? 0
        // Only bundled candidate ids and numeric scores are public, never requests or error descriptions.
        let topID = candidates?.first?.id ?? "none"
        let topScore = candidates?.first?.score ?? 0
        let count = candidates?.count ?? 0
        logger.notice("Model call=\(kind, privacy: .public) outcome=\(outcome, privacy: .public) ms=\(milliseconds, privacy: .public) availability=\(availability, privacy: .public) errorType=\(errorType, privacy: .public) errorCode=\(errorCode, privacy: .public) topCandidate=\(topID, privacy: .public) topScore=\(topScore, privacy: .public) candidates=\(count, privacy: .public)")
    }

    static func fallback(after error: Error, call: String) {
        // The shared access layer already logged measured failures with the original error metadata.
        guard !(error is PlannerModelFailure) else { return }
        let reason = PlannerModelAccess.reason(for: error)
        modelCall(call, outcome: reason.outcome, milliseconds: 0, reason: reason, error: error)
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
            let fallbackAnswer = try await fallback.extractIntent(from: utterance)
            return BrainAnswer(value: fallbackAnswer.value.normalizingPlaces(), source: fallbackAnswer.source,
                               latencyMilliseconds: (error as? PlannerModelFailure)?.milliseconds ?? fallbackAnswer.latencyMilliseconds,
                               fallbackReason: PlannerModelAccess.reason(for: error))
        }

        // Parse every sentence again, filling only absent model values.
        let keywords = try await fallback.extractIntent(from: utterance).value.normalizingPlaces()
        var intent = answer.value.normalizingPlaces()
        var didFill = false
        if intent.kind == .unknown, keywords.kind == .planJourney,
           keywords.origin != nil || keywords.destination != nil {
            intent.intent = .planJourney
            didFill = true
        }
        if intent.origin == nil,
           let origin = keywords.origin {
            intent.origin = origin
            didFill = true
        }
        if intent.destination == nil,
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
            let fallbackAnswer = try await fallback.extractPlace(from: answer, for: slot)
            return BrainAnswer(value: PlaceNormalization.normalize(fallbackAnswer.value), source: fallbackAnswer.source,
                               latencyMilliseconds: (error as? PlannerModelFailure)?.milliseconds ?? fallbackAnswer.latencyMilliseconds,
                               fallbackReason: PlannerModelAccess.reason(for: error))
        }

        // The model can return a whole sentence rather than just the place.
        var place: String?
        if let modelPlace = PlaceNormalization.normalize(modelAnswer.value) {
            let cleaned = try await fallback.extractPlace(from: modelPlace, for: slot).value
            place = PlaceNormalization.normalize(cleaned)
        }
        if place == nil {
            let cleaned = try await fallback.extractPlace(from: answer, for: slot).value
            place = PlaceNormalization.normalize(cleaned)
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
    @MainActor static func makeDefault(modelAccess: PlannerModelAccess? = nil) -> TaskPlannerBrain {
        #if canImport(FoundationModels)
        return ResilientTaskPlannerBrain(primary: FoundationModelsBrain(modelAccess: modelAccess), fallback: KeywordFallbackBrain())
        #else
        return KeywordFallbackBrain()
        #endif
    }
}
