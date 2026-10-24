// Adapted from a prior prototype, used with permission.

#if canImport(FoundationModels)
import FoundationModels
import Foundation

@available(iOS 26.0, *)
@MainActor
final class FoundationModelsBrain: TaskPlannerBrain, @unchecked Sendable {
    let initialSource: BrainSource = .onDeviceModel
    private static let callTimeout: Duration = .seconds(10)
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    private let extractionInstructions = """
    Extract the public transport journey intent, origin, destination and mode. \
    Use plan_journey only for a journey request; otherwise unknown. \
    Use nil for missing fields. Each place is at most five words. \
    Handle both from X to Y and to Y from X. \
    Omit filler. Do not invent places or expand abbreviations.
    """

    private let conversationInstructions = """
    Help plan a public transport journey. Give one short, friendly spoken sentence. \
    Only ask for a missing place or confirm the stated journey. \
    No filler, emoji or markdown. Never state times, platforms, routes, lines, \
    frequencies or prices. You have no live transport data.
    """

    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        try await measuredCall("extractIntent") {
            let session = LanguageModelSession(instructions: self.extractionInstructions)
            let response = try await session.respond(
                to: utterance,
                generating: JourneyIntent.self,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 120)
            )
            return response.content
        }
    }

    @Generable
    struct PlaceAnswer: Sendable {
        @Guide(description: "A short station, suburb or place name of at most 5 words, without filler. Nil if none is clear.")
        var place: String?
    }

    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        try await measuredCall("extractPlace") {
            let session = LanguageModelSession(instructions: "Extract a short place name of at most five words for the journey's \(slot.rawValue). Do not invent or correct places. Ignore hesitation and polite filler. Return nil if no place is clear.")
            let response = try await session.respond(
                to: answer, generating: PlaceAnswer.self,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 40)
            )
            let place = response.content.place?.trimmingCharacters(in: .whitespacesAndNewlines)
            return place?.isEmpty == false ? place : nil
        }
    }

    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String> {
        let prompt: String
        switch missing {
        case .origin:
            prompt = "The user wants to go to \(currentIntent.destination ?? "their destination") but hasn't said where they're leaving from. Ask them one short, natural question to find out."
        case .destination:
            prompt = "The user wants to leave from \(currentIntent.origin ?? "their origin") but hasn't said where they're going. Ask them one short, natural question to find out."
        }
        return try await measuredCall("clarifyingQuestion") {
            let session = LanguageModelSession(instructions: self.conversationInstructions)
            let response = try await session.respond(
                to: prompt, options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 60)
            )
            return response.content
        }
    }

    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String> {
        let prompt = "The user wants to travel from \(intent.origin ?? "?") to \(intent.destination ?? "?"). Say one short, friendly line confirming you'll help them plan that journey now, right before opening PTV."
        return try await measuredCall("confirmationLine") {
            let session = LanguageModelSession(instructions: self.conversationInstructions)
            let response = try await session.respond(
                to: prompt, options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 60)
            )
            return response.content
        }
    }

    private func measuredCall<Value: Sendable>(
        _ kind: String,
        operation: @escaping @MainActor @Sendable () async throws -> Value
    ) async throws -> BrainAnswer<Value> {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let value = try await PlannerCallDeadline.run(timeout: Self.callTimeout, operation: operation)
            let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
            PlannerDiagnostics.modelCall(kind, outcome: "ok", milliseconds: ms)
            return BrainAnswer(value: value, source: .onDeviceModel, latencyMilliseconds: ms)
        } catch {
            let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
            PlannerDiagnostics.modelCall(kind, outcome: error is PlannerCallTimeout ? "timeout" : "error", milliseconds: ms)
            throw error
        }
    }
}
#endif
