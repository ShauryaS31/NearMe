import XCTest
@testable import NearMe

@MainActor
final class ResilientTaskPlannerBrainTests: XCTestCase {
    func testKeywordFillForMissingAndWhitespaceSlots() async throws {
        for (sentence, origin, destination) in tripParsingCases {
            let model = StubModelBrain(intent: JourneyIntent(intent: .planJourney, destination: " \n", origin: nil, mode: nil))
            let brain = ResilientTaskPlannerBrain(primary: model, fallback: KeywordFallbackBrain())
            let answer = try await brain.extractIntent(from: sentence)
            XCTAssertEqual(normalizedPlace(answer.value.origin), normalizedPlace(origin), sentence)
            XCTAssertEqual(normalizedPlace(answer.value.destination), normalizedPlace(destination), sentence)
            XCTAssertEqual(answer.source, .onDeviceModelWithKeywordFill)
        }
    }

    func testKeywordFillNeverOverwritesModelPlacesOrMode() async throws {
        let model = StubModelBrain(intent: JourneyIntent(intent: .planJourney, destination: "Model destination", origin: "Model origin", mode: "bus"))
        let brain = ResilientTaskPlannerBrain(primary: model, fallback: KeywordFallbackBrain())
        let answer = try await brain.extractIntent(from: "train from Central to Holsworthy")
        XCTAssertEqual(answer.value.origin, "Model origin")
        XCTAssertEqual(answer.value.destination, "Model destination")
        XCTAssertEqual(answer.value.mode, "bus")
        XCTAssertEqual(answer.source, .onDeviceModel)
    }

    func testFillOneSlotPreservesOtherModelValue() async throws {
        let model = StubModelBrain(intent: JourneyIntent(intent: .planJourney, destination: "Model destination", origin: "", mode: nil))
        let brain = ResilientTaskPlannerBrain(primary: model, fallback: KeywordFallbackBrain())
        let answer = try await brain.extractIntent(from: "from Central to Holsworthy")
        XCTAssertEqual(answer.value.origin, "Central")
        XCTAssertEqual(answer.value.destination, "Model destination")
        XCTAssertEqual(answer.source, .onDeviceModelWithKeywordFill)
    }

    func testAllThrownModelAnswersFallBack() async throws {
        let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(shouldThrow: true), fallback: KeywordFallbackBrain())
        let intent = try await brain.extractIntent(from: "from Central to Holsworthy")
        let place = try await brain.extractPlace(from: "I'm leaving from Central", for: .origin)
        let question = try await brain.clarifyingQuestion(for: .origin, currentIntent: .empty)
        let confirmation = try await brain.confirmationLine(for: .empty)
        XCTAssertEqual(intent.value.origin, "Central")
        XCTAssertEqual(intent.value.destination, "Holsworthy")
        XCTAssertEqual(place.value, "Central")
        for source in [intent.source, place.source, question.source, confirmation.source] {
            XCTAssertEqual(source, .keywordFallback)
        }
    }

    func testSuccessfulModelAnswersKeepTheirSourceAndNilPlace() async throws {
        let brain = ResilientTaskPlannerBrain(primary: StubModelBrain(), fallback: KeywordFallbackBrain())
        let place = try await brain.extractPlace(from: "um", for: .destination)
        let question = try await brain.clarifyingQuestion(for: .origin, currentIntent: .empty)
        let confirmation = try await brain.confirmationLine(for: .empty)
        XCTAssertNil(place.value)
        for source in [place.source, question.source, confirmation.source] {
            XCTAssertEqual(source, .onDeviceModel)
        }
    }
}

private struct StubModelBrain: TaskPlannerBrain {
    let initialSource: BrainSource = .onDeviceModel
    var intent: JourneyIntent = .empty
    var shouldThrow = false

    private func answer<T: Sendable>(_ value: T) throws -> BrainAnswer<T> {
        if shouldThrow { throw NSError(domain: "TestModel", code: 1) }
        return BrainAnswer(value: value, source: .onDeviceModel)
    }

    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> { try answer(intent) }
    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> { try self.answer(nil as String?) }
    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> BrainAnswer<String> { try answer("Where are you leaving from?") }
    func confirmationLine(for intent: JourneyIntent) async throws -> BrainAnswer<String> { try answer("Let's plan that journey.") }
}
