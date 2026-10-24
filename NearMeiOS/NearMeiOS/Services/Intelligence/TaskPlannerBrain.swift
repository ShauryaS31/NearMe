// Adapted from a prior prototype, used with permission.

import Foundation

protocol TaskPlannerBrain: Sendable {
    /// Parses a user utterance into a structured journey intent.
    func extractIntent(from utterance: String) async throws -> JourneyIntent

    /// Produces the single follow-up question to ask when `missing` is the
    /// only thing standing between the current intent and taking action.
    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> String

    /// The short confirmation line spoken once every required slot is filled,
    /// right before NearMe opens PTV.
    func confirmationLine(for intent: JourneyIntent) async throws -> String
}

/// Wraps a primary brain with a deterministic fallback, mirroring
/// `VoiceInputRouter`'s ElevenLabs -> Apple Speech pattern: if the primary
/// throws at *generation* time — not just at the availability check
/// `TaskPlannerBrainFactory` does up front — retry immediately with the
/// fallback rather than dead-ending the conversation. This matters because
/// `SystemLanguageModel.default.availability` reporting `.available` is not
/// a guarantee every subsequent `LanguageModelSession.respond` call will
/// succeed (e.g. in the Simulator, or when on-device model assets are still
/// being provisioned) — those show up as a generic
/// `FoundationModels.LanguageModelSession.GenerationError` at call time.
final class ResilientTaskPlannerBrain: TaskPlannerBrain, @unchecked Sendable {
    private let primary: TaskPlannerBrain
    private let fallback: TaskPlannerBrain

    init(primary: TaskPlannerBrain, fallback: TaskPlannerBrain) {
        self.primary = primary
        self.fallback = fallback
    }

    func extractIntent(from utterance: String) async throws -> JourneyIntent {
        do {
            return try await primary.extractIntent(from: utterance)
        } catch {
            return try await fallback.extractIntent(from: utterance)
        }
    }

    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> String {
        do {
            return try await primary.clarifyingQuestion(for: missing, currentIntent: currentIntent)
        } catch {
            return try await fallback.clarifyingQuestion(for: missing, currentIntent: currentIntent)
        }
    }

    func confirmationLine(for intent: JourneyIntent) async throws -> String {
        do {
            return try await primary.confirmationLine(for: intent)
        } catch {
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
        return KeywordFallbackBrain()
    }
}
