import Foundation
import XCTest
@testable import NearMe

@MainActor
final class ModelEvalTests: XCTestCase {
    func testTripSentencesThroughResilientBrain() async throws {
        guard ProcessInfo.processInfo.environment["NEARME_MODEL_EVAL"] == "1" else {
            throw XCTSkip("Set NEARME_MODEL_EVAL=1 to run real-model evaluation.")
        }
        #if canImport(FoundationModels)
        guard FoundationModelsBrain.isAvailable else {
            throw XCTSkip("Foundation Models is unavailable on this device.")
        }
        let brain = ResilientTaskPlannerBrain(primary: FoundationModelsBrain(), fallback: KeywordFallbackBrain())
        let cases: [(String, String?, String)] = [
            ("I wanna go from Central to Holsworthy", "Central", "Holsworthy"),
            ("to Parramatta from Town Hall", "Town Hall", "Parramatta"),
            ("I need to get to Town Hall", nil, "Town Hall")
        ]
        for (sentence, origin, destination) in cases {
            let clock = ContinuousClock()
            let start = clock.now
            do {
                let answer = try await PlannerCallDeadline.run(timeout: .seconds(20)) {
                    try await brain.extractIntent(from: sentence)
                }
                let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
                print("EVAL | \(sentence) | origin=\(answer.value.origin ?? "nil") destination=\(answer.value.destination ?? "nil") kind=\(answer.value.kind.rawValue) | \(answer.source.label) | \(ms) ms")
                XCTAssertLessThan(ms, 20_000, sentence)
                XCTAssertEqual(answer.value.kind, .planJourney, sentence)
                XCTAssertEqual(normalizedPlace(answer.value.origin), normalizedPlace(origin), sentence)
                XCTAssertEqual(normalizedPlace(answer.value.destination), normalizedPlace(destination), sentence)
            } catch {
                let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
                print("EVAL | \(sentence) | origin=nil destination=nil kind=unknown | no answer | \(ms) ms")
                XCTFail("Sentence failed or exceeded 20 seconds: \(sentence): \(error)")
            }
        }
        #else
        throw XCTSkip("Foundation Models framework is unavailable.")
        #endif
    }
}
