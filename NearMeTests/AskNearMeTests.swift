import AVFoundation
import Foundation
import XCTest
@testable import NearMe

@MainActor private final class AskFakeCapture: AskCapturing {
    var onResult: ((String) -> Void)?
    var onFailure: (() -> Void)?
    var onSpeech: (() -> Void)?
    var onMediaChanged: (() -> Void)?
    var onRecognitionEnded: (() -> Void)?
    var otherAudio = false
    var recognitionActive = false
    var resumes = 0
    var starts = 0
    var finishes = 0
    var stops = 0
    var fails = false
    var onStart: (() -> Void)?
    func start() throws {
        onStart?()
        starts += 1
        if fails { throw VoiceInputError.microphoneUnavailable }
    }
    func resumeRecognition() throws { resumes += 1; recognitionActive = true }
    func pauseRecognition() { recognitionActive = false }
    func finish() { finishes += 1; complete("repeat") }
    func complete(_ text: String) { pauseRecognition(); onResult?(text) }
    func stop() { stops += 1; recognitionActive = false }
}

@MainActor private final class AskFakeActivity: AskActivityPresenting {
    var onDismiss: (() -> Void)?
    var starts = 0
    var ends = 0
    var fails = false
    var updates: [AskWidgetState] = []
    func start(id: UUID, expiresAt: Date) throws {
        starts += 1
        if fails { throw VoiceInputError.microphoneUnavailable }
    }
    func update(_ state: AskWidgetState) async { updates.append(state) }
    func end() async { ends += 1 }
}

@MainActor private final class AskHarness {
    let input = AskFakeCapture()
    let activity = AskFakeActivity()
    var allowed = true
    var prepares = 0
    var cancels = 0
    var words: [String] = []
    var states: [AskWidgetState] = []
    var spoken: [String] = []
    var clock = Date(timeIntervalSince1970: 100)
    var suspendSubmit = false
    var pendingSubmit: CheckedContinuation<Void, Never>?
    var settles = 0
    var onSettle: (() -> Void)?
    lazy var session = AskNearMeSession(input: input, activity: activity,
        allowed: { [unowned self] in allowed },
        prepare: { [unowned self] in prepares += 1 },
        submit: { [unowned self] text in
            XCTAssertFalse(input.recognitionActive, "Recognition must ignore NearMe output")
            words.append(text)
            if suspendSubmit { await withCheckedContinuation { pendingSubmit = $0 } }
            return .ready
        },
        say: { [unowned self] text in
            XCTAssertFalse(input.recognitionActive, "Check-in and goodbye must not enter recognition")
            spoken.append(text)
        },
        cancel: { [unowned self] in cancels += 1 },
        publish: { [unowned self] state in states.append(state) },
        now: { [unowned self] in clock },
        settle: { [unowned self] in settles += 1; onSettle?() },
        sleep: { _ in throw CancellationError() })
}

@MainActor final class AskNearMeTests: XCTestCase {
    func testSetupGateNeverActivatesMicrophoneOrActivity() async {
        let harness = AskHarness()
        harness.allowed = false
        await harness.session.start()
        XCTAssertEqual(harness.session.state.phase, .setup)
        XCTAssertEqual(harness.input.starts, 0)
        XCTAssertEqual(harness.activity.starts, 0)
    }

    func testListeningIsPublishedOnlyAfterHardwareStartAndRepeatedStartDoesNotToggle() async throws {
        let harness = AskHarness()
        harness.input.onStart = {
            XCTAssertEqual(harness.session.state.phase, .starting)
            XCTAssertFalse(harness.states.contains { $0.phase == .listening })
            XCTAssertEqual(harness.activity.starts, 1)
        }
        await harness.session.start()
        let id = try XCTUnwrap(harness.session.state.sessionID)
        XCTAssertEqual(harness.session.state.phase, .listening)
        await harness.session.start()
        XCTAssertEqual(harness.session.state.sessionID, id)
        XCTAssertEqual(harness.input.starts, 1)
        XCTAssertEqual(harness.input.finishes, 0)
        await harness.session.stop(id: id)
    }

    func testAudioOrActivityFailureNeverClaimsListeningAndCleansUp() async {
        for failureIsAudio in [true, false] {
            let harness = AskHarness()
            harness.input.fails = failureIsAudio
            harness.activity.fails = !failureIsAudio
            await harness.session.start()
            XCTAssertEqual(harness.session.state.phase, .failed)
            XCTAssertFalse(harness.states.contains { $0.phase == .listening })
            XCTAssertFalse(harness.session.isActive)
            XCTAssertEqual(harness.activity.ends, 1)
            XCTAssertGreaterThan(harness.input.stops, 0)
        }
    }

    func testStopDiscardsLateResultAndStaleButtonsCannotStopNewTurn() async throws {
        let harness = AskHarness()
        await harness.session.start()
        let old = try XCTUnwrap(harness.session.state.sessionID)
        await harness.session.stop(id: old)
        harness.input.onResult?("discard me")
        await Task.yield()
        XCTAssertTrue(harness.words.isEmpty)
        await harness.session.start()
        let current = try XCTUnwrap(harness.session.state.sessionID)
        await harness.session.stop(id: old)
        harness.session.finish(id: old)
        XCTAssertEqual(harness.session.state.sessionID, current)
        XCTAssertEqual(harness.input.finishes, 0)
        await harness.session.stop(id: current)
    }

    func testFinishRoutesTranscriptAndAutomaticallyListensForFollowUp() async throws {
        let harness = AskHarness()
        await harness.session.start()
        let id = try XCTUnwrap(harness.session.state.sessionID)
        harness.session.finish(id: id)
        harness.session.finish(id: id)
        for _ in 0..<100 { if harness.input.resumes == 2 { break }; await Task.yield() }
        XCTAssertEqual(harness.input.finishes, 1)
        XCTAssertEqual(harness.words, ["repeat"])
        XCTAssertEqual(harness.session.state.phase, .listening)
        XCTAssertEqual(harness.input.starts, 1, "Follow-ups reuse hardware")
        XCTAssertEqual(harness.activity.ends, 0)
        harness.input.complete("slower")
        for _ in 0..<100 { if harness.input.resumes == 3 { break }; await Task.yield() }
        XCTAssertEqual(harness.words, ["repeat", "slower"])
        XCTAssertEqual(harness.input.starts, 1)
        await harness.session.stop(id: id)
    }

    func testDismissalStopsCaptureWithoutSubmitting() async {
        let harness = AskHarness()
        await harness.session.start()
        harness.activity.onDismiss?()
        for _ in 0..<100 { if !harness.session.isActive { break }; await Task.yield() }
        XCTAssertEqual(harness.session.state.phase, .stopped)
        XCTAssertTrue(harness.words.isEmpty)
        XCTAssertGreaterThan(harness.input.stops, 0)
    }

    func testPersistedStateExpiresAndContainsOnlyStatusAndTiming() throws {
        let date = Date(timeIntervalSince1970: 100)
        let state = AskWidgetState(phase: .listening, sessionID: UUID(), startedAt: date,
                                   expiresAt: date.addingTimeInterval(45))
        XCTAssertEqual(state.current(at: date).phase, .listening)
        XCTAssertEqual(state.current(at: date.addingTimeInterval(45)).phase, .statusUnavailable)
        XCTAssertEqual(state.current(at: date.addingTimeInterval(45)).sessionID, state.sessionID)
        let data = try JSONEncoder().encode(state)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["phase", "sessionID", "startedAt", "expiresAt", "continueInApp"]))
    }

    func testOwnAudioActivationDoesNotLookLikeHeadphoneRemoval() {
        XCTAssertFalse(AskNearMeCapture.isRouteLoss(AVAudioSession.RouteChangeReason.categoryChange.rawValue))
        XCTAssertFalse(AskNearMeCapture.isRouteLoss(AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue))
        XCTAssertTrue(AskNearMeCapture.isRouteLoss(AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue))
        XCTAssertTrue(AskNearMeCapture.isRouteLoss(AVAudioSession.RouteChangeReason.noSuitableRouteForCategory.rawValue))
    }

    func testExplicitSetupURLDoesNotAcceptUnknownPaths() throws {
        XCTAssertTrue(AskWidgetStore.isSetupURL(try XCTUnwrap(URL(string: "nearme://ask"))))
        for value in ["https://ask", "nearme://ask/other", "nearme://ask?record=true", "nearme://other"] {
            XCTAssertFalse(AskWidgetStore.isSetupURL(try XCTUnwrap(URL(string: value))))
        }
    }

    func testSetupWaitsForOnboardingAndContinueDoesNotPresentPermissionSheet() throws {
        let suite = "AskOnboardingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = AppCoordinator(guides: [], defaults: defaults)
        coordinator.handleOpenURL(try XCTUnwrap(URL(string: "nearme://ask")))
        XCTAssertEqual(coordinator.route, .welcome)
        XCTAssertFalse(coordinator.showsWidgetSetup)
        coordinator.advanceFromHowItWorks()
        XCTAssertEqual(coordinator.route, .session)
        XCTAssertTrue(coordinator.showsWidgetSetup)
        coordinator.handleOpenURL(try XCTUnwrap(URL(string: "nearme://ask/continue")))
        XCTAssertEqual(coordinator.route, .session)
        XCTAssertFalse(coordinator.showsWidgetSetup)
    }

    func testSilenceChecksOnceThenWaitExtendsWithoutNaggingAndEnds() async throws {
        let harness = AskHarness()
        await harness.session.start()
        let id = try XCTUnwrap(harness.session.state.sessionID)
        await harness.session.silenceElapsed(id: id)
        XCTAssertEqual(harness.spoken, ["Do you still need me?"])
        XCTAssertTrue(harness.session.awaitingCheckIn)
        XCTAssertEqual(harness.session.state.expiresAt, harness.clock.addingTimeInterval(20))
        harness.input.complete("one minute")
        for _ in 0..<100 { if harness.input.resumes == 3 { break }; await Task.yield() }
        XCTAssertTrue(harness.words.isEmpty, "Wait must preserve the guide, not route as a new request")
        XCTAssertEqual(harness.session.state.expiresAt, harness.clock.addingTimeInterval(90))
        XCTAssertFalse(harness.session.awaitingCheckIn)
        await harness.session.silenceElapsed(id: id)
        XCTAssertEqual(harness.spoken.filter { $0 == "Do you still need me?" }.count, 1)
        XCTAssertEqual(harness.spoken.last, "I'll stop listening now. Goodbye.")
        XCTAssertEqual(harness.session.state.phase, .stopped)
        XCTAssertEqual(harness.input.stops, 1)
    }

    func testYesAndNoRouteNormallyAndOnlyAnswerTheActualCheckIn() async throws {
        let harness = AskHarness()
        await harness.session.start()
        let id = try XCTUnwrap(harness.session.state.sessionID)
        harness.input.complete("yes")
        for _ in 0..<100 { if harness.input.resumes == 2 { break }; await Task.yield() }
        harness.input.complete("no thanks")
        for _ in 0..<100 { if harness.input.resumes == 3 { break }; await Task.yield() }
        XCTAssertEqual(harness.words, ["yes", "no thanks"])
        await harness.session.silenceElapsed(id: id)
        harness.input.complete("yes please")
        for _ in 0..<100 { if harness.input.resumes == 5 { break }; await Task.yield() }
        XCTAssertEqual(harness.words, ["yes", "no thanks"])
        XCTAssertFalse(harness.session.awaitingCheckIn)
        harness.input.complete("yes")
        for _ in 0..<100 { if harness.input.resumes == 6 { break }; await Task.yield() }
        XCTAssertEqual(harness.words, ["yes", "no thanks", "yes"])
        await harness.session.stop(id: id)
    }

    func testSpokenStopEndsCaptureWithoutSubmittingAGuideStop() async throws {
        for phrase in ["stop", "end", "please stop"] {
            let harness = AskHarness()
            await harness.session.start()
            harness.input.complete(phrase)
            for _ in 0..<100 { if !harness.session.isActive { break }; await Task.yield() }
            XCTAssertTrue(harness.words.isEmpty)
            XCTAssertEqual(harness.session.state.phase, .stopped)
        }
    }

    func testEmptyFinalAndRecognitionMaintenanceDoNotResetQuietDeadline() async throws {
        let harness = AskHarness()
        await harness.session.start()
        let id = try XCTUnwrap(harness.session.state.sessionID)
        let deadline = harness.session.state.expiresAt
        harness.clock = harness.clock.addingTimeInterval(10)
        harness.input.complete("")
        for _ in 0..<100 { if harness.input.resumes == 2 { break }; await Task.yield() }
        XCTAssertEqual(harness.session.state.expiresAt, deadline)
        harness.clock = harness.clock.addingTimeInterval(10)
        harness.input.onRecognitionEnded?()
        for _ in 0..<100 { if harness.input.resumes == 3 { break }; await Task.yield() }
        XCTAssertEqual(harness.session.state.expiresAt, deadline)
        await harness.session.stop(id: id)
    }

    func testMediaAndUnsolicitedGuideSpeechPauseRecognition() async throws {
        let harness = AskHarness()
        await harness.session.start()
        let id = try XCTUnwrap(harness.session.state.sessionID)
        harness.session.externalSpeechChanged(true)
        XCTAssertFalse(harness.input.recognitionActive)
        XCTAssertEqual(harness.session.state.phase, .answering)
        harness.session.externalSpeechChanged(false)
        for _ in 0..<100 { if harness.input.resumes == 2 { break }; await Task.yield() }
        harness.input.otherAudio = true
        harness.input.onMediaChanged?()
        for _ in 0..<100 { if harness.session.state.phase == .paused { break }; await Task.yield() }
        XCTAssertFalse(harness.input.recognitionActive)
        harness.input.otherAudio = false
        harness.input.onMediaChanged?()
        for _ in 0..<100 { if harness.input.resumes == 3 { break }; await Task.yield() }
        XCTAssertTrue(harness.input.recognitionActive)
        XCTAssertEqual(harness.input.starts, 1)
        await harness.session.stop(id: id)
    }

    func testStopOrAbsoluteLimitDuringReplyCannotRearmAfterLateCompletion() async throws {
        for goodbye in [false, true] {
            let harness = AskHarness()
            harness.suspendSubmit = true
            await harness.session.start()
            let id = try XCTUnwrap(harness.session.state.sessionID)
            harness.input.complete("repeat")
            for _ in 0..<100 { if harness.pendingSubmit != nil { break }; await Task.yield() }
            XCTAssertNotNil(harness.pendingSubmit)
            if goodbye { await harness.session.goodbye(id: id) }
            else { await harness.session.stop(id: id) }
            harness.pendingSubmit?.resume(); harness.pendingSubmit = nil
            for _ in 0..<100 { await Task.yield() }
            XCTAssertEqual(harness.input.resumes, 1)
            XCTAssertFalse(harness.input.recognitionActive)
            XCTAssertFalse(harness.session.isActive)
        }
    }

    func testGuideSpeechDuringEitherStartupSettleWaitsForPlaybackCompletion() async throws {
        // The first settle precedes hardware; the second precedes recognition.
        for interruptedSettle in [1, 2] {
            let harness = AskHarness()
            harness.onSettle = { [unowned harness] in
                if harness.settles == interruptedSettle {
                    harness.session.externalSpeechChanged(true)
                }
            }
            await harness.session.start()
            let id = try XCTUnwrap(harness.session.state.sessionID)
            XCTAssertEqual(harness.input.starts, 1)
            XCTAssertEqual(harness.input.resumes, 0)
            XCTAssertFalse(harness.input.recognitionActive)
            XCTAssertEqual(harness.session.state.phase, .answering)
            harness.session.externalSpeechChanged(false)
            for _ in 0..<100 { if harness.input.resumes == 1 { break }; await Task.yield() }
            XCTAssertTrue(harness.input.recognitionActive)
            XCTAssertEqual(harness.session.state.phase, .listening)
            XCTAssertEqual(harness.input.starts, 1)
            await harness.session.stop(id: id)
        }
    }

    func testPlaybackCompletingBeforeHardwareStartupDoesNotPrematurelyStartRecognition() async throws {
        let harness = AskHarness()
        harness.onSettle = { [unowned harness] in
            if harness.settles == 1 {
                harness.session.externalSpeechChanged(true)
                harness.session.externalSpeechChanged(false)
                XCTAssertEqual(harness.input.starts, 0)
                XCTAssertEqual(harness.input.resumes, 0)
            }
        }
        await harness.session.start()
        XCTAssertEqual(harness.input.starts, 1)
        XCTAssertEqual(harness.input.resumes, 1)
        await harness.session.stop(id: try XCTUnwrap(harness.session.state.sessionID))
    }

    func testBackgroundMediaMonitorEmitsOnlyTransitionsAndStopsWithTheSession() {
        var playing = false
        var transitions: [Bool] = []
        let monitor = AskMediaMonitor(read: { playing }, changed: { transitions.append($0) },
                                      sleep: { throw CancellationError() })
        monitor.start()
        monitor.check()
        XCTAssertTrue(transitions.isEmpty)
        playing = true
        monitor.check()
        monitor.check()
        playing = false
        monitor.check()
        XCTAssertEqual(transitions, [true, false], "Background playback start and end need no OS notification")
        monitor.stop()
        playing = true
        monitor.check()
        XCTAssertEqual(transitions, [true, false], "No callbacks after microphone-session teardown")
        monitor.start()
        monitor.check()
        playing = false
        monitor.check()
        XCTAssertEqual(transitions, [true, false, false], "Restart samples its new baseline without a duplicate event")
        monitor.stop()
    }
}
