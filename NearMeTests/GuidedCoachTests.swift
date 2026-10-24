import Foundation
import XCTest
@testable import NearMe

@MainActor
enum RouterAcceptance {
    static let cases: [(String, HelpRoute)] = [
        ("can you help me send an image to my mom", .guide("whatsapp_send_photo")),
        ("send pictures to my son on whatsapp", .guide("whatsapp_send_photo")),
        ("photo bhejna hai whatsapp pe", .guide("whatsapp_send_photo")),
        ("the text is too small I can't read", .guide("iphone_text_bigger")),
        ("video call my daughter", .guide("whatsapp_video_call")),
        ("I want to practise planning a train trip", .practiceTripPlanner),
        ("how do I change my ringtone", .general)
    ]
}

/// Existing journey/voice tests explicitly opt into practice with a fake router.
/// They must not depend on installed model or embedding assets.
@MainActor
struct PracticeOnlyTestRouter: HelpRouting {
    func route(_ request: String) async -> BrainAnswer<HelpChoice> {
        BrainAnswer(value: HelpChoice(route: .practiceTripPlanner), source: .keywordFallback)
    }
}

@MainActor
final class GuidedCoachTests: XCTestCase {
    func testAllBundledGuidesPassTheContentValidator() throws {
        let guides = try GuideLibrary.load()
        XCTAssertEqual(guides.count, 15)
        XCTAssertEqual(Set(guides.map(\.id)).count, 15)
        XCTAssertTrue(guides.allSatisfy { !$0.steps.isEmpty && $0.steps.allSatisfy { !$0.uiLabelHint.isEmpty } })
        for id in ["whatsapp_send_photo", "whatsapp_video_call", "whatsapp_voice_message"] {
            XCTAssertEqual(try guide(id).steps[2].labelIsNearby, true)
        }
        XCTAssertEqual(try guide("connect_wifi").steps[3].labelIsNearby, true)
        for id in ["facetime_contact", "send_text_message"] {
            XCTAssertEqual(try guide(id).steps[3].labelIsNearby, true)
        }
    }

    func testLibraryRejectsSchemaAndEditorialViolations() throws {
        let directory = try XCTUnwrap(Bundle.main.url(forResource: "guides", withExtension: nil))
        let text = try String(contentsOf: directory.appendingPathComponent("connect_wifi.json"), encoding: .utf8)
        let mutations = [
            text.replacingOccurrences(of: "\"id\":", with: "\"unknown\": true,\n  \"id\":"),
            text.replacingOccurrences(of: "\"title\":", with: "\"id\": \"connect_wifi\",\n  \"title\":"),
            text.replacingOccurrences(of: "\"label_is_nearby\": true", with: "\"label_is_nearby\": \"true\""),
            text.replacingOccurrences(of: "\"label_is_nearby\": true", with: "\"label_is_nearby\": null"),
            text.replacingOccurrences(of: "2026-10-24", with: "2026-02-30"),
            text.replacingOccurrences(of: "Connect to Wi-Fi", with: " Connect to Wi-Fi"),
            text.replacingOccurrences(of: "Tap the name", with: "Click the name"),
            text.replacingOccurrences(of: "Tap the name", with: "Tap Alice and open the name"),
            text.replacingOccurrences(of: "Tap the name", with: "Type your password in the name"),
            text.replacingOccurrences(of: "Connect to Wi-Fi", with: "Connect for $5"),
            text.replacingOccurrences(of: "Connect to Wi-Fi", with: "Connect at 5 miles"),
            text.replacingOccurrences(of: "Connect to Wi-Fi", with: "App-prefs:WIFI"),
            text.replacingOccurrences(of: "Connect to Wi-Fi", with: "Connect—now"),
            text.replacingOccurrences(of: "  \"id\"", with: "    \"id\"")
        ]
        for mutation in mutations {
            XCTAssertThrowsError(try GuideLibrary.decode(Data(mutation.utf8), filename: "connect_wifi"))
        }
        XCTAssertThrowsError(try GuideLibrary.decode(Data(text.utf8), filename: "different_id"))
    }

    func testPrefilterAndKeywordFallbackAcceptancePhrases() async throws {
        let guides = try GuideLibrary.load()
        let router = HelpRouter(guides: guides, service: CoachModelService(brain: nil), useEmbeddings: false)
        for (request, expected) in RouterAcceptance.cases {
            let candidates = GuidePrefilter.rank(request: request, guides: guides)
            XCTAssertEqual(candidates.count, 3)
            if case .guide(let id) = expected { XCTAssertTrue(candidates.contains { $0.id == id }, request) }
            let answer = await router.route(request)
            XCTAssertEqual(answer.value.route, expected, request)
            XCTAssertEqual(answer.source, .keywordFallback)
        }
        XCTAssertEqual(GuidePrefilter.rank(request: "how do I send a photo on WhatsApp", guides: guides).first?.id, "whatsapp_send_photo")
        XCTAssertEqual(GuidePrefilter.rank(request: "make the writing bigger", guides: guides).first?.id, "iphone_text_bigger")
    }

    func testCosineAndCombinedRanking() throws {
        XCTAssertEqual(GuidePrefilter.cosine([1, 0], [1, 0]), 1, accuracy: 0.0001)
        XCTAssertEqual(GuidePrefilter.cosine([1, 0], [0, 1]), 0, accuracy: 0.0001)
        XCTAssertEqual(GuidePrefilter.cosine([0, 0], [0, 0]), 0)
        XCTAssertEqual(GuidePrefilter.cosine([1], [1, 2]), 0)
        let guides = try GuideLibrary.load()
        let entries: [(String, [Double])] = guides.map { guide -> (String, [Double]) in
            let vector: [Double] = guide.id == "set_alarm" ? [1, 0] : [0, 1]
            return (guide.id, vector)
        }
        let vectors: [String: [Double]] = Dictionary(uniqueKeysWithValues: entries)
        let ranked = GuidePrefilter.rank(request: "unmatched", guides: guides, requestVector: [1, 0], guideVectors: vectors)
        XCTAssertEqual(ranked.first?.id, "set_alarm")
        XCTAssertEqual(ranked.first?.score ?? 0, 0.2, accuracy: 0.0001)
        for (request, expected) in RouterAcceptance.cases {
            if case .guide(let id) = expected {
                XCTAssertTrue(GuidePrefilter.rank(request: request, guides: guides, requestVector: [1, 0], guideVectors: vectors).contains { $0.id == id })
            }
        }
    }

    func testFakeModelRoutesExactlyAndRejectsIdsOutsideCandidates() async throws {
        let guides = try GuideLibrary.load()
        let brain = CoachTestBrain()
        let service = CoachModelService(brain: brain, modelAccess: PlannerModelAccess(availability: { .available }))
        let router = HelpRouter(guides: guides, service: service, useEmbeddings: false)
        for (request, expected) in RouterAcceptance.cases {
            brain.choice = HelpChoice(route: expected)
            let answer = await router.route(request)
            XCTAssertEqual(answer.value.route, expected)
            XCTAssertEqual(answer.source, .onDeviceModel)
            XCTAssertEqual(brain.candidateIDs.count, 3)
        }
        brain.choice = HelpChoice(route: .guide("invented_id"))
        var answer = await router.route("send a photo")
        XCTAssertEqual(answer.value.route, .guide("whatsapp_send_photo"))
        XCTAssertEqual(answer.source, .keywordFallback)
        XCTAssertEqual(answer.fallbackReason, .rejected)
        brain.choice = HelpChoice(route: .guide("whatsapp_send_photo"), person: "none")
        answer = await router.route("send a photo on whatsapp")
        XCTAssertNil(answer.value.person)
        brain.choice = HelpChoice(route: .guide("whatsapp_send_photo"), person: "my daughter")
        answer = await router.route("send a photo to my daughter on whatsapp")
        XCTAssertEqual(answer.value.person, "your daughter")
        brain.choice = HelpChoice(route: .guide("set_alarm"))
        answer = await router.route("send a photo on whatsapp")
        XCTAssertFalse(brain.candidateIDs.contains("set_alarm"))
        XCTAssertEqual(answer.value.route, .guide("whatsapp_send_photo"))
        XCTAssertEqual(answer.fallbackReason, .rejected)
        brain.shouldThrow = true
        answer = await router.route("send pictures to my son on whatsapp")
        XCTAssertEqual(answer.value, HelpChoice(route: .guide("whatsapp_send_photo"), person: "your son"))
    }

    func testPersonNormalizationAndFallbackExtraction() {
        for word in ["mom", "Mum", "mummy", "mother", "my mom"] { XCTAssertEqual(PersonNormalization.normalize(word), "Mum") }
        for word in ["dad", "daddy", "father", "my father"] { XCTAssertEqual(PersonNormalization.normalize(word), "Dad") }
        XCTAssertEqual(PersonNormalization.normalize("my son"), "your son")
        XCTAssertEqual(PersonNormalization.normalize("my daughter"), "your daughter")
        XCTAssertEqual(PersonNormalization.normalize("aLiCe"), "Alice")
        for value in ["nil", "none", "null", "unknown", "n/a", "-", "  "] { XCTAssertNil(PersonNormalization.normalize(value)) }
        XCTAssertEqual(PersonNormalization.extract(from: "send an image to my mom"), "Mum")
        XCTAssertEqual(PersonNormalization.extract(from: "send pictures to my son on whatsapp"), "your son")
        XCTAssertEqual(PersonNormalization.extract(from: "video call my daughter"), "your daughter")
        XCTAssertEqual(PersonNormalization.extract(from: "send a photo to Alice on whatsapp"), "Alice")
        XCTAssertEqual(PersonNormalization.extract(from: "video call Mary Jane"), "Mary Jane")
        XCTAssertNil(PersonNormalization.extract(from: "connect to wifi"))
    }

    func testRewriteValidationAndNearbyPersonalisedFallbacks() throws {
        let photo = try guide("whatsapp_send_photo")
        let step = photo.steps[2]
        let personalised = CoachText.fallback(step: step, person: "mom")
        XCTAssertEqual(personalised, "Look near \"Chats\". Open your chat with Mum.")
        XCTAssertTrue(CoachText.validRewrite(personalised, guide: photo, step: step))
        XCTAssertTrue(CoachText.fallback(step: step, person: nil).contains("the person"))
        for bad in ["Tap \"Chats\".", "Look near \"Chats\". TAP \"Chats\".", "Look near \"Chats\". TAP \"cHaTs\".", "Tap \"Camera Roll\".",
                    "Look near \"Chats\". Open Mum. Send the photo.", "Look near \"Chats\". " + String(repeating: "x", count: 200),
                    "Look near \"Chats.", "Tap “Chats”.", "Tap \"chats\"."] {
            XCTAssertFalse(CoachText.validRewrite(bad, guide: photo, step: step), bad)
        }
        XCTAssertTrue(CoachText.validRewrite("Tap \"Chats\".", guide: photo, step: photo.steps[1]))
        XCTAssertEqual(CoachText.fallback(step: photo.steps[1], person: nil, stuck: true), "Tap \"Chats\". Look for \"Chats\".")
        let wifi = try guide("connect_wifi")
        XCTAssertTrue(CoachText.fallback(step: wifi.steps[3], person: nil).hasPrefix("Look near \"Wi-Fi\"."))
        XCTAssertFalse(CoachText.validRewrite("Look near \"Wi-Fi\". Tap on \"Wi-Fi\".", guide: wifi, step: wifi.steps[3]))
    }

    func testGeneralValidationAndCommandParsing() {
        XCTAssertTrue(CoachText.validGeneral(["Try opening the app.", "Look for a sound option."]))
        for invalid in [[], Array(repeating: "Look for an option.", count: 7), ["One. Two. Three."], [""],
                        ["You will find it here."], ["Tap then open the app."]] {
            XCTAssertFalse(CoachText.validGeneral(invalid))
        }
        for word in ["done", "next", "ok", "got it", " OK! "] { XCTAssertEqual(CoachCommand.parse(word), .next) }
        XCTAssertEqual(CoachCommand.parse("Repeat"), .repeatStep)
        XCTAssertEqual(CoachCommand.parse("Slower"), .slower)
        XCTAssertEqual(CoachCommand.parse("I'm stuck"), .stuck)
        XCTAssertEqual(CoachCommand.parse("I’m stuck"), .stuck)
        XCTAssertEqual(CoachCommand.parse("Stop"), .stop)
        XCTAssertNil(CoachCommand.parse("send an image"))
    }

    func testInvalidModelTextFallsBackForRewriteStuckAndGeneral() async throws {
        let brain = CoachTestBrain()
        brain.text = "Tap \"Invented\"."
        brain.steps = Array(repeating: "Do a thing.", count: 7)
        let service = CoachModelService(brain: brain, modelAccess: PlannerModelAccess(availability: { .available }))
        let photo = try guide("whatsapp_send_photo")
        for stuck in [false, true] {
            let answer = await service.rewrite(request: "send a photo", guide: photo, index: 2, person: "Mum", stuck: stuck)
            XCTAssertEqual(answer.source, .keywordFallback)
            XCTAssertEqual(answer.value, "Look near \"Chats\". Open your chat with Mum.")
            XCTAssertNotNil(answer.latencyMilliseconds)
        }
        let general = await service.general(request: "ringtone")
        XCTAssertEqual(general.value, [CoachText.generalFallback])
    }

    func testEveryAcceptanceRouteIsExclusiveInTheEngine() async throws {
        for (request, route) in RouterAcceptance.cases {
            let journey = CountingJourneyBrain()
            let model = CoachTestBrain()
            model.choice = HelpChoice(route: route)
            let engine = try makeEngine(journey: journey, model: model)
            engine.useTypedInput()
            engine.submitTypedInput(request)
            await eventually { engine.plannerState == .idle }
            if route == .practiceTripPlanner {
                XCTAssertEqual(journey.extractions, 1)
                XCTAssertNil(engine.coach)
            } else {
                XCTAssertEqual(journey.extractions, 0, request)
                XCTAssertEqual(journey.placeExtractions, 0, request)
                XCTAssertNotNil(engine.coach)
                XCTAssertNil(engine.tripPlannerPracticeViewModel)
                XCTAssertFalse(engine.conversation.contains { $0.text.contains("Where") || $0.text.contains("starting from") })
                if case .guide(let id) = route { XCTAssertEqual(engine.coach?.guide?.id, id) }
                else { XCTAssertEqual(engine.coach?.isGeneral, true) }
            }
            engine.endSession()
        }
    }

    func testCoachCommandsPersonalisationFinishAndSessionPrivacy() async throws {
        let output = CoachTestOutput()
        let engine = try makeEngine(output: output)
        engine.useTypedInput()
        engine.submitTypedInput("can you help me send an image to my mom")
        await eventually { engine.coach != nil && engine.plannerState == .idle }
        for index in 1...2 {
            engine.submitTypedInput("done")
            await eventually { engine.coach?.stepIndex == index && engine.plannerState == .idle }
        }
        XCTAssertEqual(engine.coach?.text, "Look near \"Chats\". Open your chat with Mum.")
        XCTAssertEqual(output.lines.last, engine.coach?.text)
        engine.coachCommand(.slower)
        await eventually { engine.coach?.slower == true && engine.plannerState == .idle }
        XCTAssertTrue(output.slower)
        engine.coachCommand(.stuck)
        await eventually { engine.plannerState == .idle }
        XCTAssertEqual(engine.coach?.stepIndex, 2)
        XCTAssertEqual(engine.coach?.text, "Look near \"Chats\". Open your chat with Mum.")
        engine.coachCommand(.repeatStep)
        await eventually { engine.plannerState == .idle }
        XCTAssertTrue(output.slower)
        for index in 3...6 {
            engine.coachCommand(.next)
            await eventually { engine.coach?.stepIndex == index && engine.plannerState == .idle }
        }
        engine.coachCommand(.next)
        await eventually { engine.isHome }
        XCTAssertEqual(output.lines.last, "That's it, you're done.")
        XCTAssertNil(engine.coach)
        XCTAssertTrue(engine.conversation.isEmpty)
        XCTAssertTrue(engine.liveTranscript.isEmpty)
        XCTAssertFalse(output.slower)
    }

    func testProgressPersistsOnlyIdentifiersAndCountersAndRejectsInvalidRestores() throws {
        let suite = "CoachTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CoachProgressStore(defaults: defaults)
        let photo = try guide("whatsapp_send_photo")
        let session = CoachSession(guide: photo, request: "private words", person: "Mum", generalSteps: [], stepIndex: 2, text: "private line")
        store.save(session)
        XCTAssertEqual(Set(defaults.persistentDomain(forName: suite)?.keys.map { $0 } ?? []), [CoachProgressStore.progressKey])
        let restored = try XCTUnwrap(store.restore(guides: [photo]))
        XCTAssertEqual(restored.stepIndex, 2)
        XCTAssertNil(restored.person)
        XCTAssertEqual(restored.request, "")
        XCTAssertTrue(restored.text.contains("the person"))
        store.save(CoachProgress(guideID: photo.id, stepIndex: 100, sessionID: session.id, revision: 1))
        XCTAssertNil(store.restore(guides: [photo]))
        XCTAssertNil(defaults.data(forKey: CoachProgressStore.progressKey))
        store.save(session)
        store.save(CoachSession(guide: nil, request: "private", person: nil, generalSteps: ["Try an option."], stepIndex: 0, text: "Try an option."))
        XCTAssertNil(store.restore(guides: [photo]))
        store.save(session)
        store.clear()
        XCTAssertNil(store.restore(guides: [photo]))
    }

    func testBackgroundResumeForGuideAndGeneralAndStopClearsRestore() async throws {
        for request in ["send an image to my mom", "change my ringtone"] {
            let output = CoachTestOutput()
            let engine = try makeEngine(output: output)
            engine.useTypedInput()
            engine.submitTypedInput(request)
            await eventually { engine.coach != nil && engine.plannerState == .idle }
            let before = try XCTUnwrap(engine.coach)
            engine.appEnteredBackground()
            engine.appBecameActive()
            await eventually { output.lines.last?.hasPrefix("Welcome back. You were on step 1:") == true }
            XCTAssertEqual(engine.coach?.id, before.id)
            XCTAssertEqual(engine.coach?.generalSteps, before.generalSteps)
            XCTAssertEqual(engine.coach?.person, before.person)
            engine.coachCommand(.stop)
            await eventually { engine.isHome }
            engine.restoreCoach()
            XCTAssertNil(engine.coach)
        }
    }

    func testVoiceRequestAndCommandsUseCoachWithoutJourneyExtraction() async throws {
        let input = CoachTestInput()
        let output = CoachTestOutput()
        let journey = CountingJourneyBrain()
        let engine = try makeEngine(journey: journey, output: output, input: input)
        input.nextTranscript = "can you help me send an image to my mom"
        engine.userTappedToTalk()
        await eventually { engine.coach != nil && engine.plannerState == .idle }
        XCTAssertEqual(engine.coach?.guide?.id, "whatsapp_send_photo")
        XCTAssertEqual(engine.coach?.person, "Mum")
        for index in 1...2 {
            input.nextTranscript = "next"
            engine.userTappedToTalk()
            await eventually { engine.coach?.stepIndex == index && engine.plannerState == .idle }
        }
        XCTAssertEqual(output.lines.last, "Look near \"Chats\". Open your chat with Mum.")
        XCTAssertEqual(journey.extractions, 0)
        XCTAssertEqual(journey.placeExtractions, 0)
        input.nextTranscript = "stop"
        engine.userTappedToTalk()
        await eventually { engine.isHome }
        XCTAssertNil(engine.coach)
    }

    func testRelaunchRestoresAnonymousGuideAndSpeaksWelcome() async throws {
        let suite = "CoachRelaunch.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CoachProgressStore(defaults: defaults)
        let photo = try guide("whatsapp_send_photo")
        store.save(CoachSession(guide: photo, request: "send a photo to Mum", person: "Mum", generalSteps: [], stepIndex: 2, text: "private"))
        let output = CoachTestOutput()
        let engine = try makeEngine(output: output, store: store)
        engine.restoreCoach()
        await eventually { engine.coach?.stepIndex == 2 && engine.plannerState == .idle && !output.lines.isEmpty }
        XCTAssertNil(engine.coach?.person)
        XCTAssertEqual(engine.coach?.request, "")
        XCTAssertTrue(output.lines.last?.hasPrefix("Welcome back. You were on step 3:") == true)
        XCTAssertFalse(output.lines.last?.contains("Mum") == true)
        engine.coachCommand(.stop)
        await eventually { engine.isHome }
        XCTAssertNil(store.restore(guides: [photo]))
    }

    func testStopWhileRouterIsPendingCannotStartACoachLater() async throws {
        let model = CoachTestBrain()
        model.suspendRoute = true
        model.choice = HelpChoice(route: .guide("whatsapp_send_photo"), person: "Mum")
        let engine = try makeEngine(model: model)
        engine.useTypedInput()
        engine.submitTypedInput("send an image to my mom")
        await eventually { model.pendingRoute != nil }
        engine.cancelCurrentAction()
        model.releaseRoute()
        await eventually { model.routeReturned }
        // Let the service's deadline stream and engine continuation drain.
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(engine.isHome)
        XCTAssertNil(engine.coach)
        XCTAssertTrue(engine.conversation.isEmpty)
        XCTAssertNil(engine.tripPlannerPracticeViewModel)
    }

    func testNextRewriteIsPreparedBeforeAdvancing() async throws {
        let model = CoachTestBrain()
        model.choice = HelpChoice(route: .guide("whatsapp_send_photo"))
        let engine = try makeEngine(model: model)
        engine.useTypedInput()
        engine.submitTypedInput("send a photo on whatsapp")
        await eventually { model.rewrittenHints.contains("Chats") && engine.plannerState == .idle }
        XCTAssertEqual(engine.coach?.stepIndex, 0)
        XCTAssertEqual(model.rewrittenHints.prefix(2).map { $0 }, ["WhatsApp", "Chats"])
        engine.coachCommand(.next)
        await eventually { engine.coach?.stepIndex == 1 && engine.plannerState == .idle && model.rewrittenHints.count >= 3 }
        XCTAssertEqual(model.rewrittenHints, ["WhatsApp", "Chats", "Chats"], "Reuse the prepared second step; prepare only the third step")
        engine.endSession()
    }

    private func guide(_ id: String) throws -> HelpGuide {
        try XCTUnwrap(GuideLibrary.load().first { $0.id == id })
    }

    private func makeEngine(journey: CountingJourneyBrain? = nil, model: CoachTestBrain? = nil,
                            output: CoachTestOutput? = nil, input: CoachTestInput? = nil,
                            store: CoachProgressStore? = nil) throws -> TaskPlannerEngine {
        let guides = try GuideLibrary.load()
        let service = CoachModelService(brain: model, modelAccess: PlannerModelAccess(availability: { .available }))
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "CoachEngineTests.\(UUID().uuidString)"))
        return TaskPlannerEngine(brain: journey ?? CountingJourneyBrain(), voiceInput: input ?? CoachTestInput(),
            voiceOutput: output ?? CoachTestOutput(), permissions: PermissionsManager(), userName: "",
            permissionCheck: { true }, settleBeforeListening: {},
            guides: guides, helpRouter: HelpRouter(guides: guides, service: service, useEmbeddings: false),
            coachService: service, coachStore: store ?? CoachProgressStore(defaults: defaults),
            appOpener: UnavailableCoachAppOpener(), activityUpdater: FakeCoachActivityUpdater())
    }

    private func eventually(_ condition: () -> Bool) async {
        // Always yield: command tasks may not have entered their busy state yet.
        await Task.yield()
        for _ in 0..<1500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Coach did not reach expected state")
    }
}

@MainActor
private final class CoachTestBrain: CoachBrain {
    var choice = HelpChoice(route: .general)
    var candidateIDs: [String] = []
    var text = "invalid rewrite"
    var steps = ["Try looking for a sound option."]
    var shouldThrow = false
    var suspendRoute = false
    var pendingRoute: CheckedContinuation<Void, Never>?
    var routeReturned = false
    var rewrittenHints: [String] = []
    func route(request: String, candidates: [GuideCandidate]) async throws -> HelpChoice {
        candidateIDs = candidates.map(\.id)
        if shouldThrow { throw CoachModelError.unavailable }
        if suspendRoute { await withCheckedContinuation { pendingRoute = $0 } }
        routeReturned = true
        return choice
    }
    func releaseRoute() {
        let continuation = pendingRoute
        pendingRoute = nil
        continuation?.resume()
    }
    func rewrite(request: String, guide: HelpGuide, step: HelpGuide.Step, person: String?, stuck: Bool) async throws -> String {
        rewrittenHints.append(step.uiLabelHint)
        return text
    }
    func general(request: String) async throws -> [String] { steps }
}

@MainActor
private final class CountingJourneyBrain: TaskPlannerBrain {
    var extractions = 0
    var placeExtractions = 0
    var initialSource: BrainSource { .keywordFallback }
    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        extractions += 1
        return BrainAnswer(value: JourneyIntent(intent: .planJourney, destination: nil, origin: nil, mode: nil), source: .keywordFallback)
    }
    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        placeExtractions += 1
        return BrainAnswer(value: nil, source: .keywordFallback)
    }
}

@MainActor
private final class CoachTestInput: VoiceInputService {
    var acceptsTranscript: () -> Bool = { true }
    var isListening = false
    var nextTranscript: String?
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        guard let nextTranscript else { throw VoiceInputError.noSpeechDetected }
        self.nextTranscript = nil
        return nextTranscript
    }
    func finishListening() {}
    func stopListening() {}
}

@MainActor
private final class CoachTestOutput: VoiceOutputService {
    var lines: [String] = []
    var slower = false
    func speak(_ text: String) async { lines.append(text) }
    func stop() {}
    func setSlower(_ slower: Bool) { self.slower = slower }
}
