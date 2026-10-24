import Foundation
import XCTest
@testable import NearMe

@MainActor
final class ModelEvalTests: XCTestCase {
    func testSevenHelpRoutesThroughRealRouter() async throws {
        try requireCoachModel()
        let guides = try GuideLibrary.load()
        let router = HelpRouter(guides: guides, service: CoachModelService.makeDefault())
        for (request, expected) in RouterAcceptance.cases {
            let clock = ContinuousClock()
            let start = clock.now
            do {
                let answer = try await PlannerCallDeadline.run(timeout: .seconds(20)) { await router.route(request) }
                let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
                print("EVAL | \(request) | route=\(answer.value.route.description) | \(answer.source.label) | \(ms) ms")
                XCTAssertEqual(answer.value.route, expected, request)
                if request == "can you help me send an image to my mom" {
                    XCTAssertEqual(answer.value.person, "Mum")
                }
                XCTAssertTrue([BrainSource.onDeviceModel, .onDeviceModelWithKeywordFill].contains(answer.source), "Router used fallback: \(request)")
                XCTAssertLessThan(ms, 20_000)
            } catch {
                let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
                print("EVAL | \(request) | route=no answer | \(ms) ms")
                XCTFail("Router failed: \(error)")
            }
        }
    }

    func testRealPersonalisedRewriteAndStuckAnswer() async throws {
        try requireCoachModel()
        let photo = try XCTUnwrap(GuideLibrary.load().first { $0.id == "whatsapp_send_photo" })
        let service = CoachModelService.makeDefault()
        for stuck in [false, true] {
            let clock = ContinuousClock()
            let start = clock.now
            let kind = stuck ? "stuck" : "rewrite Mum"
            do {
                let answer = try await PlannerCallDeadline.run(timeout: .seconds(20)) {
                    await service.rewrite(request: "can you help me send an image to my mom", guide: photo,
                                          index: 2, person: "Mum", stuck: stuck)
                }
                let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
                print("EVAL | \(kind) | \(answer.value) | \(answer.source.label) | \(ms) ms")
                XCTAssertEqual(answer.source, .onDeviceModel, "A deterministic fallback must not pass a real rewrite eval")
                XCTAssertTrue(CoachText.validRewrite(answer.value, guide: photo, step: photo.steps[2]))
                XCTAssertTrue(answer.value.contains("Mum"))
                XCTAssertLessThan(ms, 20_000)
            } catch {
                let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
                print("EVAL | \(kind) | no answer | \(ms) ms")
                XCTFail("Rewrite failed: \(error)")
            }
        }
    }

    private func requireCoachModel() throws {
        guard ProcessInfo.processInfo.environment["NEARME_MODEL_EVAL"] == "1" else {
            throw XCTSkip("Set NEARME_MODEL_EVAL=1 to run real-model evaluation.")
        }
        #if canImport(FoundationModels)
        guard FoundationModelsBrain.isAvailable else { throw XCTSkip("Foundation Models is unavailable on this device.") }
        #else
        throw XCTSkip("Foundation Models framework is unavailable.")
        #endif
    }

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
