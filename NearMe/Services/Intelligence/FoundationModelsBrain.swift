// Adapted from a prior prototype, used with permission.

#if canImport(FoundationModels)
import FoundationModels
import Foundation

@available(iOS 26.0, *)
final class FoundationModelsBrain: TaskPlannerBrain, @unchecked Sendable {
    let initialSource: BrainSource = .onDeviceModel
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
    correct spelling). Fill BOTH origin and destination whenever both are \
    said, whether the user says from X to Y or to Y from X. Exclude leading \
    phrases, trailing punctuation and polite filler such as please or thanks.
    """

    private let conversationInstructions = """
    You are NearMe, a warm, concise voice assistant that helps someone plan \
    a public transport journey using the PTV app. Speak the way a helpful \
    friend would over a phone call: short sentences, no filler, no emoji, \
    no markdown - this text is read aloud by a speech synthesizer. \
    Never state or invent times, platforms, routes, lines, frequencies or \
    prices. You have no live transport data. Only ask for a missing place \
    or confirm the user's stated origin and destination.
    """

    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        let session = LanguageModelSession(instructions: extractionInstructions)
        let response = try await session.respond(
            to: utterance,
            generating: JourneyIntent.self
        )
        return BrainAnswer(value: response.content, source: .onDeviceModel)
    }

    @Generable
    struct PlaceAnswer: Sendable {
        @Guide(description: "The station, suburb or place name only, without leading phrases or trailing filler. Nil if none is clear.")
        var place: String?
    }

    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        let session = LanguageModelSession(instructions: "Extract only the place the user gives in answer to a question about their journey's \(slot.rawValue). Do not invent or correct a place. Ignore hesitation and polite filler. Return nil if no place is clear.")
        let response = try await session.respond(to: answer, generating: PlaceAnswer.self)
        let place = response.content.place?.trimmingCharacters(in: .whitespacesAndNewlines)
        return BrainAnswer(value: place?.isEmpty == false ? place : nil, source: .onDeviceModel)
    }

    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String> {
        let session = LanguageModelSession(instructions: conversationInstructions)
        let prompt: String
        switch missing {
        case .origin:
            prompt = "The user wants to go to \(currentIntent.destination ?? "their destination") but hasn't said where they're leaving from. Ask them one short, natural question to find out."
        case .destination:
            prompt = "The user wants to leave from \(currentIntent.origin ?? "their origin") but hasn't said where they're going. Ask them one short, natural question to find out."
        }
        let response = try await session.respond(to: prompt)
        return BrainAnswer(value: response.content, source: .onDeviceModel)
    }

    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String> {
        let session = LanguageModelSession(instructions: conversationInstructions)
        let prompt = "The user wants to travel from \(intent.origin ?? "?") to \(intent.destination ?? "?"). Say one short, friendly line confirming you'll help them plan that journey now, right before opening PTV."
        let response = try await session.respond(to: prompt)
        return BrainAnswer(value: response.content, source: .onDeviceModel)
    }
}
#endif
