import AVFoundation
import Foundation
import Speech
import XCTest
@testable import NearMe

@MainActor
final class HandsFreeVoiceCommandTests: XCTestCase {
    func testInterruptionClosesWindowAndRequiresForegroundResume() {
        let f = CommandFixture()
        f.start()
        f.listener.requestAudioWindow()
        f.input.onCaptureLost?()
        XCTAssertEqual(f.listener.status, .paused)
        XCTAssertFalse(f.input.capturing)
        XCTAssertFalse(f.input.allowsOtherAudio)
        f.listener.update(guideID: f.guide, sharing: true, foreground: false)
        f.listener.requestAudioWindow()
        f.listener.resume()
        XCTAssertFalse(f.input.capturing)
        f.start()
        f.listener.resume()
        XCTAssertTrue(f.input.capturing)
        f.listener.stop()
    }

    func testExplicitAudioWindowRequiresPrefixAndExactCommandAndAcceptsOnlyOnce() async {
        let f = CommandFixture()
        f.listener.requestAudioWindow()
        XCTAssertFalse(f.input.allowsOtherAudio)
        f.input.otherAudio = true
        f.question = .playback
        f.start()
        f.listener.requestAudioWindow()
        XCTAssertTrue(f.input.allowsOtherAudio)
        XCTAssertEqual(f.listener.status, .commandWindow)
        for text in ["stop", "yes", "music near me stop", "NearMe please stop", "NearMe next week"] {
            f.input.emit(text, final: true)
            await settle()
        }
        XCTAssertTrue(f.commands.isEmpty)
        XCTAssertTrue(f.answers.isEmpty)
        f.input.emit("NEAR ME, repeat!", final: true)
        await settle()
        XCTAssertEqual(f.commands, [.repeatStep])
        XCTAssertFalse(f.input.allowsOtherAudio)
        XCTAssertEqual(f.listener.status, .waitingForAudio)
        f.input.emit("NearMe yes", final: true)
        await settle()
        XCTAssertTrue(f.answers.isEmpty)
        f.listener.requestAudioWindow()
        f.input.emit("NearMe yes", final: true)
        await settle()
        XCTAssertEqual(f.answers, ["yes"])
        XCTAssertFalse(f.input.allowsOtherAudio)
        f.listener.stop()
    }

    func testAudioWindowExpiresAndClosesOnSpeechSharingLossAndSessionChange() async {
        let f = CommandFixture()
        f.input.otherAudio = true
        f.start()
        f.listener.requestAudioWindow()
        f.now += 8
        f.input.emit("NearMe stop", final: true)
        await settle()
        XCTAssertTrue(f.commands.isEmpty)
        XCTAssertFalse(f.input.allowsOtherAudio)
        f.listener.requestAudioWindow()
        f.listener.setSpeaking(true)
        XCTAssertFalse(f.input.allowsOtherAudio)
        f.listener.setSpeaking(false)
        f.now += 0.2
        f.listener.requestAudioWindow()
        f.listener.update(guideID: f.guide, sharing: false, foreground: false)
        XCTAssertFalse(f.input.allowsOtherAudio)
        f.listener.requestAudioWindow()
        XCTAssertFalse(f.input.allowsOtherAudio)
        f.listener.update(guideID: f.guide, sharing: true, foreground: false)
        f.listener.requestAudioWindow()
        XCTAssertTrue(f.input.allowsOtherAudio)
        f.listener.update(guideID: UUID(), sharing: true, foreground: false)
        XCTAssertFalse(f.input.allowsOtherAudio)
        XCTAssertFalse(f.input.capturing)
        f.listener.stop()
    }

    func testAnswersAreBoundedAndOnlyAcceptedForThePendingQuestion() async {
        let f = CommandFixture()
        f.start()
        f.input.emit("yes", final: true)
        await settle()
        XCTAssertTrue(f.answers.isEmpty)
        f.question = .playback
        f.listener.tick()
        f.input.emit("NO, it isn't!", final: true)
        await settle()
        XCTAssertEqual(f.answers, ["no"])
        f.input.emit("a random song lyric", final: true)
        await settle()
        XCTAssertEqual(f.answers, ["no"])
        f.question = .description
        f.listener.tick()
        f.input.emit("I can see a keyboard", final: false)
        f.now += 1.19
        f.listener.tick()
        XCTAssertEqual(f.answers.count, 1)
        f.now += 0.02
        f.listener.tick()
        await settle()
        XCTAssertEqual(f.answers.last, "I can see a keyboard")
        for unsafe in [String(repeating: "a", count: 161), "password sunflower", "code 123456", "me@example.test"] {
            XCTAssertNil(ScreenVoiceAnswer.bounded(unsafe, question: .description))
        }
        let prefixedSecret = VoiceCommand.prefixedPayload("NearMe, me@example.test")
        XCTAssertEqual(prefixedSecret, "me@example.test")
        XCTAssertNil(prefixedSecret.flatMap { ScreenVoiceAnswer.bounded($0, question: .description) })
        f.listener.stop()
    }

    func testQuestionChangeOtherAudioAndNearMeSpeechDiscardPendingAnswers() async {
        let f = CommandFixture()
        f.question = .playback
        f.start()
        f.input.emit("yes", final: false)
        f.question = .reopen
        f.now += 2
        f.listener.tick()
        await settle()
        XCTAssertTrue(f.answers.isEmpty)
        f.input.otherAudio = true
        XCTAssertEqual(f.listener.status, .waitingForAudio)
        XCTAssertEqual(f.listener.status.text, "Pause other audio, or use Check & listen")
        f.input.emit("yes", final: true)
        f.input.otherAudio = false
        f.listener.setSpeaking(true)
        f.input.emit("yes", final: true)
        f.listener.setSpeaking(false)
        f.now += 0.2
        f.listener.tick()
        await settle()
        XCTAssertTrue(f.answers.isEmpty)
        f.input.emit("yes please", final: true)
        await settle()
        XCTAssertEqual(f.answers, ["yes"])
        f.listener.stop()
    }

    func testCompletionCanReleaseMicrophoneWithoutCancellingItsAnswerTask() async {
        let f = CommandFixture()
        f.question = .playback
        var cancelled: Bool?
        f.listener.onAnswer = { _, _ in
            f.listener.stop(cancelAction: false)
            cancelled = Task.isCancelled
        }
        f.start()
        f.input.emit("yes", final: true)
        await settle()
        XCTAssertEqual(cancelled, false)
        XCTAssertFalse(f.input.capturing)
        XCTAssertEqual(f.listener.status, .off)
    }

    func testEveryPhraseCasePunctuationAndSuffix() {
        let cases: [(String, VoiceCommand)] = [
            ("what's next", .whatsNext), ("what next", .whatsNext), ("what now", .whatsNext),
            ("next step", .whatsNext), ("next", .next), ("help", .help),
            ("repeat", .repeatStep), ("I'm stuck", .stuck), ("stuck", .stuck), ("stop", .stop)
        ]
        for (phrase, command) in cases {
            XCTAssertEqual(VoiceCommand.match(phrase), command)
            XCTAssertEqual(VoiceCommand.match(phrase.uppercased() + "?!"), command)
            XCTAssertEqual(VoiceCommand.match("Please, " + phrase), command)
        }
        XCTAssertEqual(VoiceCommand.match("WHAT’S NEXT?"), .whatsNext)
        XCTAssertEqual(VoiceCommand.match("I’m stuck."), .stuck)
        for text in ["", "play a song", "next week please", "help me search", "repeat this song", "nonstop", "context"] {
            XCTAssertNil(VoiceCommand.match(text), text)
        }
    }

    func testStartsOnlyWithGuideSharingAndForegroundThenSurvivesHandoff() {
        let f = CommandFixture()
        let guide = UUID()
        f.listener.update(guideID: nil, sharing: true, foreground: true)
        f.listener.update(guideID: guide, sharing: false, foreground: true)
        f.listener.update(guideID: guide, sharing: true, foreground: false)
        XCTAssertEqual(f.input.starts, 0)
        f.listener.update(guideID: guide, sharing: true, foreground: true)
        XCTAssertEqual(f.input.starts, 1)
        XCTAssertEqual(f.listener.status.text, "Listening for commands")
        f.listener.update(guideID: guide, sharing: true, foreground: false)
        XCTAssertTrue(f.input.capturing)
        f.listener.update(guideID: nil, sharing: true, foreground: false)
        XCTAssertFalse(f.input.capturing)
        XCTAssertEqual(f.listener.status, .off)
    }

    func testStopIsLatchedUntilAnotherGuideOrExplicitResume() {
        let f = CommandFixture()
        f.start()
        f.listener.stop()
        f.start()
        XCTAssertEqual(f.input.starts, 1)
        XCTAssertFalse(f.input.capturing)
        f.listener.update(guideID: UUID(), sharing: true, foreground: true)
        XCTAssertEqual(f.input.starts, 2)
        f.listener.stop()
    }

    func testLongSharingConsentWaitDoesNotDisableFirstForegroundStart() {
        let f = CommandFixture()
        f.listener.update(guideID: f.guide, sharing: false, foreground: true)
        f.now += 30
        f.listener.update(guideID: f.guide, sharing: false, foreground: true)
        f.start()
        XCTAssertTrue(f.input.capturing)
        f.listener.stop()
    }

    func testFailedMicrophoneStartCannotRetryInBackground() {
        let f = CommandFixture()
        f.input.failCapture = true
        f.start()
        f.now += 1
        f.listener.update(guideID: f.guide, sharing: true, foreground: false)
        XCTAssertEqual(f.input.starts, 1)
        XCTAssertEqual(f.listener.status, .paused)
        XCTAssertFalse(f.input.capturing)
    }

    func testSharingLossHasTenSecondGraceAndRecoveryWithinGrace() {
        let f = CommandFixture()
        f.start()
        f.now = 104
        f.listener.update(guideID: f.guide, sharing: false, foreground: false)
        f.now = 113.9
        f.listener.update(guideID: f.guide, sharing: false, foreground: false)
        XCTAssertTrue(f.input.capturing)
        f.listener.update(guideID: f.guide, sharing: true, foreground: false)
        f.now = 120
        f.listener.update(guideID: f.guide, sharing: false, foreground: false)
        f.now = 130.01
        f.listener.update(guideID: f.guide, sharing: false, foreground: false)
        XCTAssertFalse(f.input.capturing)
        XCTAssertEqual(f.listener.status, .off)
    }

    func testStablePartialAndFinalRestartWithoutAcceptingOtherSpeech() async {
        let f = CommandFixture()
        f.start()
        f.input.emit("next", final: false)
        f.now += 0.5
        f.listener.tick()
        XCTAssertTrue(f.commands.isEmpty)
        f.input.emit("next week", final: false)
        f.now += 1
        f.listener.tick()
        XCTAssertTrue(f.commands.isEmpty)
        f.input.emit("please HELP!", final: false)
        f.now += 0.61
        f.listener.tick()
        await settle()
        XCTAssertEqual(f.commands, [.help])
        XCTAssertEqual(f.input.recognitionStarts, 2)
        f.input.emit("random conversation", final: true)
        XCTAssertEqual(f.input.recognitionStarts, 3)
        f.input.emit("repeat", final: true)
        await settle()
        XCTAssertEqual(f.commands, [.help, .repeatStep])
        XCTAssertEqual(f.input.starts, 1, "Recognition restarts must retain foreground capture")
        f.listener.stop()
    }

    func testNoRecognitionDuringSpeechOrSettleAndLateResultsAreDiscarded() async {
        let f = CommandFixture()
        f.start()
        f.input.emit("stop", final: false)
        f.listener.setSpeaking(true)
        XCTAssertFalse(f.input.recognizing)
        XCTAssertTrue(f.input.capturing)
        f.input.emit("stop", final: true)
        f.now += 2
        f.listener.tick()
        f.listener.setSpeaking(false)
        f.now += 0.149
        f.listener.tick()
        f.input.emit("stop", final: true)
        await settle()
        XCTAssertTrue(f.commands.isEmpty)
        XCTAssertFalse(f.input.recognizing)
        f.now += 0.002
        f.listener.tick()
        XCTAssertTrue(f.input.recognizing)
        f.input.emit("help", final: true)
        await settle()
        XCTAssertEqual(f.commands, [.help])
        f.listener.stop()
    }

    func testOtherAudioHintPausesAndResumesWithoutRestartingMicrophone() async {
        let f = CommandFixture()
        f.input.otherAudio = true
        f.start()
        XCTAssertTrue(f.input.capturing)
        XCTAssertFalse(f.input.recognizing)
        f.input.emit("stop", final: true)
        await settle()
        XCTAssertTrue(f.commands.isEmpty)
        f.input.otherAudio = false
        XCTAssertTrue(f.input.recognizing)
        f.input.emit("help", final: false)
        f.input.otherAudio = true
        f.now += 1
        f.listener.tick()
        XCTAssertFalse(f.input.recognizing)
        f.input.otherAudio = false
        f.input.emit("next", final: true)
        await settle()
        XCTAssertEqual(f.commands, [.next])
        XCTAssertEqual(f.input.starts, 1)
        f.listener.stop()
    }

    func testErrorsBackOffOneTwoFiveThenRequireForegroundTap() {
        let f = CommandFixture()
        f.input.failRecognition = true
        f.start()
        XCTAssertEqual(f.input.recognitionStarts, 1)
        for (time, count) in [(100.9, 1), (101.0, 2), (102.9, 2), (103.0, 3), (107.9, 3), (108.0, 4)] {
            f.now = time
            f.listener.tick()
            XCTAssertEqual(f.input.recognitionStarts, count)
        }
        XCTAssertEqual(f.listener.status.text, "Voice commands paused, tap to resume")
        XCTAssertFalse(f.input.capturing)
        f.input.failRecognition = false
        f.listener.update(guideID: f.guide, sharing: true, foreground: false)
        f.listener.resume()
        XCTAssertFalse(f.input.capturing)
        f.start()
        XCTAssertFalse(f.input.capturing, "Foregrounding alone does not bypass the retry limit")
        f.listener.resume()
        XCTAssertTrue(f.input.recognizing)
        f.listener.stop()
    }

    func testTimeoutAndCallbackErrorBothRestartAfterBackoff() {
        let f = CommandFixture()
        f.start()
        f.now = 155
        f.listener.tick()
        XCTAssertFalse(f.input.recognizing)
        f.now = 156
        f.listener.tick()
        XCTAssertEqual(f.input.recognitionStarts, 2)
        f.input.onFailure?()
        f.now = 157.9
        f.listener.tick()
        XCTAssertEqual(f.input.recognitionStarts, 2)
        f.now = 158
        f.listener.tick()
        XCTAssertEqual(f.input.recognitionStarts, 3)
        f.listener.stop()
    }

    func testSessionOptionsAndOnDeviceVocabulary() {
        let listening = NearMeAudioSession.guidanceOptions(speaking: false)
        XCTAssertTrue(listening.contains(.mixWithOthers))
        XCTAssertTrue(listening.contains(.defaultToSpeaker))
        XCTAssertTrue(listening.contains(.allowBluetoothA2DP))
        XCTAssertFalse(listening.contains(.duckOthers))
        let speaking = NearMeAudioSession.guidanceOptions(speaking: true)
        XCTAssertTrue(speaking.contains(.duckOthers))
        XCTAssertTrue(speaking.contains(.mixWithOthers))
        XCTAssertEqual(speaking.subtracting(.duckOthers), listening)
        let request = OnDeviceCommandSpeechInput.makeRequest()
        XCTAssertTrue(request.requiresOnDeviceRecognition)
        XCTAssertTrue(request.shouldReportPartialResults)
        XCTAssertEqual(request.contextualStrings, VoiceCommand.recognitionPhrases)
    }

    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }
}

@MainActor
private final class CommandClock { var now = 100.0 }

@MainActor
private final class CommandFixture {
    let input = FakeCommandSpeechInput()
    let guide = UUID()
    private let clock = CommandClock()
    let listener: HandsFreeVoiceCommands
    var commands: [VoiceCommand] = []
    var question: ScreenCoachLoop.Question?
    var answers: [String] = []
    var now: TimeInterval {
        get { clock.now }
        set { clock.now = newValue }
    }
    init() {
        let clock = self.clock
        listener = HandsFreeVoiceCommands(input: input, now: { clock.now })
        listener.onCommand = { [weak self] in self?.commands.append($0) }
        listener.pendingQuestion = { [weak self] in self?.question }
        listener.onAnswer = { [weak self] answer, _ in self?.answers.append(answer) }
    }
    func start() { listener.update(guideID: guide, sharing: true, foreground: true) }
}

@MainActor
final class FakeCommandSpeechInput: CommandSpeechInput {
    var allowsOtherAudio = false
    var onResult: ((String, Bool) -> Void)?
    var onFailure: (() -> Void)?
    var onCaptureLost: (() -> Void)?
    var onAudioHint: (() -> Void)?
    var otherAudio = false { didSet { onAudioHint?() } }
    var capturing = false
    var recognizing = false
    var starts = 0
    var recognitionStarts = 0
    var failRecognition = false
    var failCapture = false
    func startCapture() throws {
        starts += 1
        if failCapture { throw VoiceInputError.microphoneUnavailable }
        capturing = true
    }
    func startRecognition() throws {
        recognitionStarts += 1
        if failRecognition { throw VoiceInputError.recognizerUnavailable }
        recognizing = true
    }
    func pauseRecognition() { recognizing = false }
    func stopCapture() { capturing = false; recognizing = false }
    // Deliberately delivers even while paused to test the controller's second gate.
    func emit(_ text: String, final: Bool) { onResult?(text, final) }
}
