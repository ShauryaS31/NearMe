import Foundation
import XCTest
@testable import NearMe

@MainActor
final class HelpAcknowledgementTests: XCTestCase {
    func testTypedAcknowledgementRunsWithRouterAndFinishesBeforeGuideSpeech() async throws {
        let fixture = try AcknowledgementFixture()
        defer { fixture.engine.endSession() }
        fixture.engine.useTypedInput()
        fixture.engine.submitTypedInput(fixture.request)
        await eventually { fixture.output.pending != nil && fixture.router.pending != nil }
        XCTAssertEqual(fixture.output.lines, [fixture.line])
        XCTAssertNil(fixture.engine.firstAudioMilliseconds)
        fixture.output.onPlaybackStarted?()
        let firstAudio = try XCTUnwrap(fixture.engine.firstAudioMilliseconds)
        fixture.router.release()
        await eventually { fixture.router.returned }
        XCTAssertNil(fixture.engine.coach, "Guide speech must wait for acknowledgement completion")
        fixture.output.finish()
        await eventually { fixture.engine.coach != nil && fixture.engine.plannerState == .idle }
        XCTAssertEqual(fixture.engine.firstAudioMilliseconds, firstAudio)
        XCTAssertEqual(fixture.engine.coach?.person, "Mum")
        for command in ["done", "repeat", "slower", "I'm stuck"] {
            fixture.engine.submitTypedInput(command)
            await eventually { fixture.engine.plannerState == .idle }
        }
        XCTAssertEqual(fixture.output.lines.filter { $0 == fixture.line }.count, 1)
        XCTAssertEqual(fixture.output.overlaps, 0)
    }

    func testSpeechEndAcknowledgesBeforeFinalTranscriptWithoutDiscardingFinalWords() async throws {
        let fixture = try AcknowledgementFixture()
        defer { fixture.engine.endSession() }
        fixture.engine.userTappedToTalk()
        await eventually { fixture.input.pending != nil }
        fixture.input.endSpeech("send an image")
        await eventually { fixture.output.pending != nil }
        XCTAssertEqual(fixture.engine.plannerState, .finishing)
        XCTAssertTrue(fixture.input.acceptsTranscript(), "Stopped capture can finish decoding during acknowledgement")
        fixture.output.onPlaybackStarted?()
        XCTAssertNotNil(fixture.engine.firstAudioMilliseconds)
        fixture.input.finish(fixture.request)
        await eventually { fixture.router.pending != nil }
        XCTAssertEqual(fixture.router.request, fixture.request)
        XCTAssertEqual(fixture.engine.liveTranscript, fixture.request)
        fixture.router.release()
        fixture.output.finish()
        await eventually { fixture.engine.coach != nil && fixture.engine.plannerState == .idle }
        XCTAssertEqual(fixture.engine.coach?.person, "Mum")
        XCTAssertEqual(fixture.output.lines.filter { $0 == fixture.line }.count, 1)
        XCTAssertEqual(fixture.output.overlaps, 0)
    }

    func testStopDuringAcknowledgementPreventsLateGuideSpeech() async throws {
        let fixture = try AcknowledgementFixture()
        fixture.engine.useTypedInput()
        fixture.engine.submitTypedInput(fixture.request)
        await eventually { fixture.output.pending != nil && fixture.router.pending != nil }
        fixture.engine.endSession()
        fixture.router.release()
        await eventually { fixture.router.returned }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(fixture.engine.coach)
        XCTAssertTrue(fixture.engine.isHome)
        XCTAssertEqual(fixture.output.lines, [fixture.line])
    }

    func testHomeCommandsAndPracticePlaceAnswersDoNotAcknowledge() async throws {
        for command in ["Done", "Repeat", "Slower", "I'm stuck", "Stop"] {
            let fixture = try AcknowledgementFixture()
            fixture.engine.useTypedInput()
            fixture.engine.submitTypedInput(command)
            await eventually { fixture.engine.plannerState == .idle }
            XCTAssertTrue(fixture.output.lines.isEmpty)
            XCTAssertNil(fixture.router.request)
            fixture.engine.endSession()
        }
        let fixture = try AcknowledgementFixture()
        fixture.engine.startPractice()
        await eventually { fixture.input.pending != nil }
        fixture.engine.useTypedInput()
        fixture.engine.submitTypedInput("Town Hall")
        await eventually { fixture.engine.plannerState == .idle }
        XCTAssertFalse(fixture.output.lines.contains(fixture.line))
        fixture.engine.endSession()
    }

    private func eventually(_ condition: () -> Bool) async {
        await Task.yield()
        for _ in 0..<1500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Expected acknowledgement state was not reached")
    }
}

@MainActor
private final class AcknowledgementFixture {
    let request = "can you help me send an image to my mom"
    let line = "Sure, let me help you with that."
    let input = AcknowledgementInput()
    let output = AcknowledgementOutput()
    let router = AcknowledgementRouter()
    let engine: TaskPlannerEngine

    init() throws {
        let guides = try GuideLibrary.load()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "Acknowledgement.\(UUID().uuidString)"))
        engine = TaskPlannerEngine(brain: KeywordFallbackBrain(), voiceInput: input, voiceOutput: output,
            permissions: PermissionsManager(), userName: "", permissionCheck: { true }, settleBeforeListening: {},
            guides: guides, helpRouter: router, coachService: CoachModelService(brain: nil),
            coachStore: CoachProgressStore(defaults: defaults), appOpener: UnavailableCoachAppOpener())
    }
}

@MainActor
private final class AcknowledgementRouter: HelpRouting {
    var request: String?
    var pending: CheckedContinuation<Void, Never>?
    var returned = false
    func route(_ request: String) async -> BrainAnswer<HelpChoice> {
        self.request = request
        await withCheckedContinuation { pending = $0 }
        returned = true
        return BrainAnswer(value: HelpChoice(route: .guide("whatsapp_send_photo")), source: .onDeviceModel)
    }
    func release() { let value = pending; pending = nil; value?.resume() }
}

@MainActor
private final class AcknowledgementOutput: VoiceOutputService {
    var onPlaybackStarted: (() -> Void)?
    var pending: CheckedContinuation<Void, Never>?
    var lines: [String] = []
    var overlaps = 0
    func speakAcknowledgement(_ text: String) async {
        lines.append(text)
        await withCheckedContinuation { pending = $0 }
    }
    func speak(_ text: String) async {
        if pending != nil { overlaps += 1 }
        lines.append(text)
    }
    func finish() { let value = pending; pending = nil; value?.resume() }
    func stop() { finish() }
}

@MainActor
private final class AcknowledgementInput: VoiceInputService {
    var isListening = false
    var acceptsTranscript: () -> Bool = { true }
    var onSpeechEnd: ((String) -> Void)?
    var lastTurn = SpeechTurn()
    var pending: CheckedContinuation<String, Error>?
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        isListening = true
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func endSpeech(_ text: String) {
        isListening = false
        lastTurn.endedAt = ProcessInfo.processInfo.systemUptime
        onSpeechEnd?(text)
    }
    func finish(_ text: String) {
        let value = pending
        pending = nil
        value?.resume(returning: text)
    }
    func finishListening() { endSpeech("") }
    func stopListening() {
        isListening = false
        let value = pending
        pending = nil
        value?.resume(throwing: CancellationError())
    }
}
