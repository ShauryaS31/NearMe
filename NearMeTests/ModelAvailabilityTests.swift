import Foundation
import XCTest
#if canImport(FoundationModels)
import FoundationModels
#endif
@testable import NearMe

@MainActor
final class ModelAvailabilityTests: XCTestCase {
    func testCancelledCallReportsCancelledOutcome() async {
        let access = PlannerModelAccess(availability: { .available })
        do {
            let _: BrainAnswer<String> = try await access.run("cancelled-test") {
                throw CancellationError()
            }
            XCTFail("A cancelled call must fail")
        } catch {
            let reason = PlannerModelAccess.reason(for: error)
            XCTAssertEqual(reason, .cancelled)
            XCTAssertEqual(reason.outcome, "cancelled")
        }
    }

    func testUnavailableAssetsReportModelNotReady() {
        #if canImport(FoundationModels)
        let error = LanguageModelSession.GenerationError.assetsUnavailable(.init(debugDescription: "Test assets unavailable"))
        let reason = PlannerModelAccess.reason(for: error)
        XCTAssertEqual(reason, .unavailable(.modelNotReady))
        XCTAssertEqual(reason.label, "model not ready")
        #endif
    }

    func testUnavailableAtConstructionButReadyAtFirstRouteUsesModel() async throws {
        let probe = MutableModelAvailability()
        let brain = AvailabilityCoachBrain()
        let access = PlannerModelAccess(availability: { probe.read() })
        let service = CoachModelService(brain: brain, modelAccess: access)
        let router = HelpRouter(guides: try GuideLibrary.load(), service: service, useEmbeddings: false)
        XCTAssertEqual(probe.reads, 0, "Construction must not decide availability")

        probe.value = .available
        let answer = await router.route("send a photo on WhatsApp")
        XCTAssertEqual(probe.reads, 1)
        XCTAssertEqual(brain.calls, ["router"])
        XCTAssertEqual(answer.source, .onDeviceModel)
        XCTAssertNil(answer.fallbackReason)
    }

    func testHighKeywordScoreStillConsultsModelBeforeOverridingGeneral() async throws {
        let brain = AvailabilityCoachBrain()
        let guides = try GuideLibrary.load()
        let service = CoachModelService(brain: brain, modelAccess: PlannerModelAccess(availability: { .available }))
        let router = HelpRouter(guides: guides, service: service, useEmbeddings: false)
        let request = "send a photo on WhatsApp"
        let ranked = GuidePrefilter.rank(request: request, guides: guides)
        XCTAssertEqual(ranked.first?.score, 1)
        XCTAssertEqual(GuidePrefilter.fallback(request: request, candidates: ranked).route, .guide("whatsapp_send_photo"))

        brain.choice = HelpChoice(route: .general)
        let answer = await router.route(request)
        XCTAssertEqual(brain.calls, ["router"])
        XCTAssertEqual(answer.value.route, .guide("whatsapp_send_photo"))
        XCTAssertEqual(answer.source, .onDeviceModelWithKeywordFill)
    }

    func testCallTimeAvailabilityFallsBackAndRecoversWithoutRecreatingRouter() async throws {
        let probe = MutableModelAvailability()
        probe.value = .available
        let brain = AvailabilityCoachBrain()
        let service = CoachModelService(brain: brain, modelAccess: PlannerModelAccess(availability: { probe.read() }))
        let router = HelpRouter(guides: try GuideLibrary.load(), service: service, useEmbeddings: false)
        probe.value = .unavailable(.modelNotReady)

        let fallback = await router.route("send a photo on WhatsApp")
        XCTAssertEqual(fallback.source, .keywordFallback)
        XCTAssertEqual(fallback.value.route, .guide("whatsapp_send_photo"))
        XCTAssertEqual(fallback.fallbackReason?.label, "model not ready")
        XCTAssertTrue(brain.calls.isEmpty)

        probe.value = .available
        let recovered = await router.route("send a photo on WhatsApp")
        XCTAssertEqual(recovered.source, .onDeviceModel)
        XCTAssertNil(recovered.fallbackReason)
        XCTAssertEqual(probe.reads, 2)
        XCTAssertEqual(brain.calls, ["router"])
    }

    func testRouterMapsThrownTimeoutErrorAndRejectedOutput() async throws {
        let brain = AvailabilityCoachBrain()
        let service = CoachModelService(brain: brain, modelAccess: PlannerModelAccess(availability: { .available }))
        let router = HelpRouter(guides: try GuideLibrary.load(), service: service, useEmbeddings: false)
        let failures: [(Error, ModelFallbackReason)] = [
            (PlannerCallTimeout.exceeded, .timeout),
            (NSError(domain: "ModelTest", code: 42), .error),
            (CoachModelError.invalid, .rejected)
        ]
        for (error, reason) in failures {
            brain.failure = error
            let answer = await router.route("send a photo on WhatsApp")
            XCTAssertEqual(answer.source, .keywordFallback)
            XCTAssertEqual(answer.fallbackReason, reason)
            XCTAssertEqual(answer.value.route, .guide("whatsapp_send_photo"))
            XCTAssertNotNil(answer.latencyMilliseconds)
        }
        brain.failure = nil
        brain.choice = HelpChoice(route: .guide("invented_id"))
        let invalid = await router.route("send a photo on WhatsApp")
        XCTAssertEqual(invalid.source, .onDeviceModelWithKeywordFill)
        XCTAssertNil(invalid.fallbackReason)
        XCTAssertEqual(invalid.value.route, .guide("whatsapp_send_photo"))
    }

    func testActualDeadlineReturnsTimeoutAndNextCallCanRecover() async throws {
        let brain = AvailabilityCoachBrain()
        brain.delay = .seconds(60)
        let access = PlannerModelAccess(availability: { .available }, timeout: .milliseconds(20))
        let service = CoachModelService(brain: brain, modelAccess: access)
        let router = HelpRouter(guides: try GuideLibrary.load(), service: service, useEmbeddings: false)
        let timedOut = await router.route("send a photo on WhatsApp")
        XCTAssertEqual(timedOut.fallbackReason, .timeout)
        XCTAssertGreaterThanOrEqual(timedOut.latencyMilliseconds ?? 0, 20)
        brain.delay = nil
        let recovered = await router.route("send a photo on WhatsApp")
        XCTAssertEqual(recovered.source, .onDeviceModel)
        XCTAssertNil(recovered.fallbackReason)
    }

    func testRewriteStuckAndGeneralEachProbeAvailability() async throws {
        let probe = MutableModelAvailability()
        let brain = AvailabilityCoachBrain()
        let service = CoachModelService(brain: brain, modelAccess: PlannerModelAccess(availability: { probe.read() }))
        let guide = try XCTUnwrap(GuideLibrary.load().first { $0.id == "whatsapp_send_photo" })
        for available in [false, true, false] {
            probe.value = available ? .available : .unavailable(.appleIntelligenceNotEnabled)
            let rewrite = await service.rewrite(request: "photo", guide: guide, index: 0, person: nil)
            let stuck = await service.rewrite(request: "photo", guide: guide, index: 0, person: nil, stuck: true)
            let general = await service.general(request: "ringtone")
            let generalStuck = await service.generalStuck(step: "Try opening the app.")
            let sources: [BrainSource] = [rewrite.source, stuck.source, general.source, generalStuck.source]
            let reasons: [ModelFallbackReason?] = [rewrite.fallbackReason, stuck.fallbackReason,
                                                  general.fallbackReason, generalStuck.fallbackReason]
            for source in sources { XCTAssertEqual(source, available ? .onDeviceModel : .keywordFallback) }
            for reason in reasons {
                XCTAssertEqual(reason, available ? nil : .unavailable(.appleIntelligenceNotEnabled))
            }
        }
        XCTAssertEqual(probe.reads, 12)
        XCTAssertEqual(brain.calls, ["rewrite", "stuck", "general", "generalStuck"])
    }

    func testDefaultFactoriesRetainModelAndGateEveryExtractionWithoutModelAssets() async throws {
        #if canImport(FoundationModels)
        let probe = MutableModelAvailability()
        let access = PlannerModelAccess(availability: { probe.read() })
        let journey = TaskPlannerBrainFactory.makeDefault(modelAccess: access)
        let coach = CoachModelService.makeDefault(modelAccess: access)
        XCTAssertEqual(probe.reads, 0)
        XCTAssertEqual(journey.initialSource, .onDeviceModel)
        let intent = try await journey.extractIntent(from: "from Central to Town Hall")
        probe.value = .unavailable(.deviceNotEligible)
        let place = try await journey.extractPlace(from: "Town Hall", for: .destination)
        let general = await coach.general(request: "ringtone")
        XCTAssertEqual(intent.source, .keywordFallback)
        XCTAssertEqual(intent.fallbackReason, .unavailable(.modelNotReady))
        XCTAssertEqual(intent.value.destination, "Town Hall")
        XCTAssertEqual(place.source, .keywordFallback)
        XCTAssertEqual(place.fallbackReason, .unavailable(.deviceNotEligible))
        XCTAssertEqual(place.value, "Town Hall")
        XCTAssertEqual(general.fallbackReason, .unavailable(.deviceNotEligible))
        XCTAssertEqual(probe.reads, 3)
        #endif
    }

    func testBadgeFallbackReasonsAreShortAndKeepTwoLines() {
        let cases: [(ModelFallbackReason, String)] = [
            (.unavailable(.modelNotReady), "model not ready"),
            (.unavailable(.appleIntelligenceNotEnabled), "Apple Intelligence off"),
            (.unavailable(.deviceNotEligible), "device not eligible"),
            (.unavailable(.other), "model unavailable"),
            (.timeout, "timeout"), (.rejected, "rejected"), (.error, "error"), (.cancelled, "cancelled")
        ]
        for (reason, label) in cases {
            let badge = SessionDebugBadge(understanding: .keywordFallback, modelMilliseconds: 0,
                reply: .template, voice: "System voice", firstAudioMilliseconds: 400,
                sttMilliseconds: 50, fallbackReason: reason)
            XCTAssertEqual(badge.lines, ["Understood: Keyword fallback (\(label)), 0 ms | reply: template",
                                        "Voice: System voice, first audio 0.40 s | STT 50 ms"])
        }
    }
}

@MainActor
private final class MutableModelAvailability {
    var value: PlannerModelAvailability = .unavailable(.modelNotReady)
    var reads = 0
    func read() -> PlannerModelAvailability {
        reads += 1
        return value
    }
}

@MainActor
private final class AvailabilityCoachBrain: CoachBrain {
    var calls: [String] = []
    var choice = HelpChoice(route: .guide("whatsapp_send_photo"))
    var failure: Error?
    var delay: Duration?

    func route(request: String, candidates: [GuideCandidate]) async throws -> HelpChoice {
        calls.append("router")
        if let failure { throw failure }
        if let delay { try await Task.sleep(for: delay) }
        return choice
    }

    func rewrite(request: String, guide: HelpGuide, step: HelpGuide.Step, person: String?, stuck: Bool) async throws -> String {
        calls.append(stuck ? "stuck" : "rewrite")
        return step.instruction
    }

    func general(request: String) async throws -> [String] {
        calls.append("general")
        return ["Try opening the app."]
    }

    func generalStuck(step: String) async throws -> String {
        calls.append("generalStuck")
        return "Try opening the app."
    }
}
