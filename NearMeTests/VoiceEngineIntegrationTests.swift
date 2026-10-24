import XCTest
@testable import NearMe

@MainActor
final class VoiceEngineIntegrationTests: XCTestCase {
    func testEveryPracticeCaptionAndNextCaptionUseSharedOutput() async {
        let output = EngineVoiceOutput()
        let input = EngineVoiceInput()
        let engine = makeEngine(input: input, output: output)
        engine.useTypedInput()
        engine.submitTypedInput("travel from Central to Town Hall")
        await eventually { engine.tripPlannerPracticeViewModel != nil && output.lines.count >= 2 }
        guard let practice = engine.tripPlannerPracticeViewModel else { XCTFail("Practice did not open"); return }
        for step in PracticeStep.allCases {
            let caption = step.caption(origin: "Central", destination: "Town Hall")
            await eventually { output.lines.last == caption }
            XCTAssertEqual(practice.currentCaption, caption)
            if let next = step.next {
                XCTAssertEqual(output.prefetched.last, next.caption(origin: "Central", destination: "Town Hall"))
                practice.completeCurrentStep()
            }
        }
        XCTAssertEqual(input.starts, 0)
        engine.endSession()
    }

    func testCancelEndAndTypeImmediatelyStopPendingSpeech() async {
        for action in 0..<3 {
            let output = EngineVoiceOutput()
            output.suspend = true
            let input = EngineVoiceInput()
            let engine = makeEngine(input: input, output: output)
            engine.useTypedInput()
            engine.submitTypedInput("hello")
            await eventually { output.pending != nil }
            let stops = output.stops
            switch action {
            case 0: engine.cancelCurrentAction()
            case 1: engine.endSession()
            default: engine.useTypedInput()
            }
            XCTAssertEqual(output.stops, stops + 1)
            XCTAssertNil(output.pending)
            await Task.yield()
            XCTAssertEqual(input.starts, 0)
            XCTAssertEqual(engine.plannerState, .idle)
            engine.endSession()
        }
    }

    private func makeEngine(input: EngineVoiceInput, output: EngineVoiceOutput) -> TaskPlannerEngine {
        TaskPlannerEngine(brain: KeywordFallbackBrain(), voiceInput: input, voiceOutput: output,
                          permissions: PermissionsManager(), userName: "")
    }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<1000 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Engine did not reach expected state")
    }
}

@MainActor
private final class EngineVoiceInput: VoiceInputService {
    var isListening = false
    var starts = 0
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        starts += 1
        throw VoiceInputError.recognizerUnavailable
    }
    func stopListening() { isListening = false }
}

@MainActor
private final class EngineVoiceOutput: VoiceOutputService {
    var lines: [String] = []
    var prefetched: [String] = []
    var stops = 0
    var suspend = false
    var pending: CheckedContinuation<Void, Never>?
    func speak(_ text: String) async {
        lines.append(text)
        if suspend { await withCheckedContinuation { pending = $0 } }
    }
    func prefetch(_ text: String) { prefetched.append(text) }
    func stop() {
        stops += 1
        let continuation = pending
        pending = nil
        continuation?.resume()
    }
}
