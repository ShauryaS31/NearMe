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
    Extract the public transport journey intent, origin, destination and mode for a trip planner practice app. \
    Use plan_journey only for a journey request; otherwise unknown. \
    Use nil for missing fields. Each place is at most five words. \
    Handle both from X to Y and to Y from X. \
    Omit filler. Do not invent places or expand abbreviations.
    """

    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        try await measuredCall("extractIntent") {
            let session = LanguageModelSession(instructions: self.extractionInstructions)
            let response = try await session.respond(
                to: utterance,
                generating: JourneyIntent.self,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 120)
            )
            return response.content.normalizingPlaces()
        }
    }

    @Generable
    struct PlaceAnswer: Sendable {
        @FoundationModels.Guide(description: "A short station, suburb or place name of at most 5 words, without filler. Nil if none is clear.")
        var place: String?
    }

    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        try await measuredCall("extractPlace") {
            let session = LanguageModelSession(instructions: "Extract a short place name of at most five words for the journey's \(slot.rawValue). Do not invent or correct places. Ignore hesitation and polite filler. Return nil if no place is clear.")
            let response = try await session.respond(
                to: answer, generating: PlaceAnswer.self,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 40)
            )
            return PlaceNormalization.normalize(response.content.place)
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
