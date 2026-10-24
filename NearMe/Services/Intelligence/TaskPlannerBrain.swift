// Adapted from a prior prototype, used with permission.

import Foundation
import OSLog

enum BrainSource: String, Sendable {
    case onDeviceModel
    case onDeviceModelWithKeywordFill
    case keywordFallback

    var label: String {
        switch self {
        case .onDeviceModel: return "On-device model"
        case .onDeviceModelWithKeywordFill: return "On-device model + keyword fill"
        case .keywordFallback: return "Keyword fallback"
        }
    }
}

struct BrainAnswer<Value: Sendable>: Sendable {
    let value: Value
    let source: BrainSource
}

protocol TaskPlannerBrain: Sendable {
    var initialSource: BrainSource { get }
    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent>
    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?>
    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String>
    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String>
}

enum PlannerDiagnostics {
    static let logger = Logger(subsystem: "au.nearme.ios", category: "planner")

    static func fallback(after error: Error) {
        let nsError = error as NSError
        logger.error("Model error type=\(String(reflecting: type(of: error)), privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) description=\(nsError.localizedDescription, privacy: .public); using keyword fallback")
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
            PlannerDiagnostics.fallback(after: error)
            return try await fallback.extractIntent(from: utterance)
        }

        // Parse every sentence again, filling only absent model values.
        let keywords = try await fallback.extractIntent(from: utterance).value
        var intent = answer.value
        var didFill = false
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
        return BrainAnswer(value: intent, source: didFill ? .onDeviceModelWithKeywordFill : answer.source)
    }

    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        do {
            return try await primary.extractPlace(from: answer, for: slot)
        } catch {
            PlannerDiagnostics.fallback(after: error)
            return try await fallback.extractPlace(from: answer, for: slot)
        }
    }

    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String> {
        do {
            return try await primary.clarifyingQuestion(for: missing, currentIntent: currentIntent)
        } catch {
            PlannerDiagnostics.fallback(after: error)
            return try await fallback.clarifyingQuestion(for: missing, currentIntent: currentIntent)
        }
    }

    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String> {
        do {
            return try await primary.confirmationLine(for: intent)
        } catch {
            PlannerDiagnostics.fallback(after: error)
            return try await fallback.confirmationLine(for: intent)
        }
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
