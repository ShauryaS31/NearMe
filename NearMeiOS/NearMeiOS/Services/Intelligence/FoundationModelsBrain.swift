// Adapted from a prior prototype, used with permission.

#if canImport(FoundationModels)
import FoundationModels
import Foundation

@available(iOS 26.0, *)
final class FoundationModelsBrain: TaskPlannerBrain, @unchecked Sendable {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    private let extractionInstructions = """
    You are the intent-extraction step inside NearMe, a voice assistant that \
    helps people use the PTV (Public Transport Victoria) app hands-free. \
    Given one sentence the user just said out loud, extract their intent, \
    origin, destination, and transport mode. Only use plan_journey when they \
    clearly want to get from one place to another using public transport. \
    Leave a field nil rather than guessing when it wasn't mentioned. Keep \
    place names exactly as the user said them (don't expand abbreviations or \
    correct spelling).
    """

    private let conversationInstructions = """
    You are NearMe, a warm, concise voice assistant that helps someone plan \
    a public transport journey using the PTV app. Speak the way a helpful \
    friend would over a phone call: short sentences, no filler, no emoji, \
    no markdown — this text is read aloud by a speech synthesizer.
    """

    func extractIntent(from utterance: String) async throws -> JourneyIntent {
        let session = LanguageModelSession(instructions: extractionInstructions)
        let response = try await session.respond(
            to: utterance,
            generating: JourneyIntent.self
        )
        return response.content
    }

    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> String {
        let session = LanguageModelSession(instructions: conversationInstructions)
        let prompt: String
        switch missing {
        case .origin:
            prompt = "The user wants to go to \(currentIntent.destination ?? "their destination") but hasn't said where they're leaving from. Ask them one short, natural question to find out."
        case .destination:
            prompt = "The user wants to leave from \(currentIntent.origin ?? "their origin") but hasn't said where they're going. Ask them one short, natural question to find out."
        }
        let response = try await session.respond(to: prompt)
        return response.content
    }

    func confirmationLine(for intent: JourneyIntent) async throws -> String {
        let session = LanguageModelSession(instructions: conversationInstructions)
        let prompt = "The user wants to travel from \(intent.origin ?? "?") to \(intent.destination ?? "?"). Say one short, friendly line confirming you'll help them plan that journey now, right before opening PTV."
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
#endif
