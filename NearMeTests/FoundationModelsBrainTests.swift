import XCTest
@testable import NearMe

@MainActor
final class FoundationModelsBrainTests: XCTestCase {
    func testTripSentencesThroughResilientBrain() async throws {
        #if canImport(FoundationModels)
        guard FoundationModelsBrain.isAvailable else {
            throw XCTSkip("Foundation Models is unavailable on this device.")
        }
        let brain = ResilientTaskPlannerBrain(primary: FoundationModelsBrain(), fallback: KeywordFallbackBrain())
        for (sentence, origin, destination) in tripParsingCases {
            let answer = try await brain.extractIntent(from: sentence)
            XCTAssertEqual(answer.value.kind, .planJourney, sentence)
            XCTAssertEqual(normalizedPlace(answer.value.origin), normalizedPlace(origin), sentence)
            XCTAssertEqual(normalizedPlace(answer.value.destination), normalizedPlace(destination), sentence)
        }
        #else
        throw XCTSkip("Foundation Models framework is unavailable.")
        #endif
    }
}
