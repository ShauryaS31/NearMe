import Combine
import Foundation
import Speech
import XCTest
@testable import NearMe

@MainActor
final class OnDeviceVoiceInputTests: XCTestCase {
    func testUnsupportedLocaleShowsTypingAndNeverStartsRecognition() async {
        let capability = FakeSpeechCapability()
        let router = VoiceInputRouter(capabilities: capability, locales: [Locale(identifier: "en-AU"), Locale(identifier: "fr-FR")])
        let engine = TaskPlannerEngine(brain: KeywordFallbackBrain(), voiceInput: router,
                                       voiceOutput: InputTestOutput(), permissions: PermissionsManager(), userName: "")
        let typing = expectation(description: "Switches directly to typing")
        let subscription = engine.$isTyping.filter { $0 }.prefix(1).sink { _ in typing.fulfill() }
        engine.beginSession()
        await fulfillment(of: [typing], timeout: 1)
        XCTAssertTrue(engine.isTyping)
        XCTAssertEqual(engine.plannerState, .idle)
        XCTAssertEqual(engine.lastErrorMessage, "Speech recognition on this phone isn't available for your language yet. You can type instead.")
        XCTAssertEqual(capability.checked.map(\.identifier), ["en-AU", "fr-FR"])
        XCTAssertEqual(capability.input.startCount, 0)
        XCTAssertFalse(router.isListening)
        subscription.cancel()
        engine.endSession()
    }

    func testRouterTriesDeviceLocaleAfterEnAUAndUsesOnlySelectedLocalService() async throws {
        let capability = FakeSpeechCapability()
        capability.supportedIdentifier = "fr-FR"
        let router = VoiceInputRouter(capabilities: capability, locales: [Locale(identifier: "en-AU"), Locale(identifier: "fr-FR")])
        let text = try await router.startListening { _ in }
        XCTAssertEqual(text, "Local transcript")
        XCTAssertEqual(capability.checked.map(\.identifier), ["en-AU", "fr-FR"])
        XCTAssertEqual(capability.input.startCount, 1)
    }

    func testEveryLegacyRecognitionRequestRequiresOnDeviceRecognition() {
        for _ in 0..<3 {
            let request = AppleSpeechFallbackService.makeRecognitionRequest()
            XCTAssertTrue(request.requiresOnDeviceRecognition)
            XCTAssertTrue(request.shouldReportPartialResults)
        }
    }

    func testTemporaryUnavailabilityUsesExistingMessageAndDoesNotStart() async {
        let capability = FakeSpeechCapability()
        capability.unavailable = true
        let router = VoiceInputRouter(capabilities: capability)
        do {
            _ = try await router.startListening { _ in }
            XCTFail("Unavailable recognizer must not start")
        } catch {
            XCTAssertTrue(VoiceDiagnostics.message(for: error).hasPrefix("Speech recognition isn't available right now. You can type instead."))
        }
        XCTAssertEqual(capability.input.startCount, 0)
    }
}

@MainActor
private final class FakeSpeechCapability: OnDeviceSpeechCapabilityChecking {
    let input = LocalTestInput()
    var supportedIdentifier: String?
    var unavailable = false
    var checked: [Locale] = []
    func service(for locale: Locale) async throws -> VoiceInputService? {
        checked.append(locale)
        if unavailable { throw VoiceInputError.recognizerUnavailable }
        return locale.identifier == supportedIdentifier ? input : nil
    }
}

@MainActor
private final class LocalTestInput: VoiceInputService {
    var isListening = false
    var startCount = 0
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        startCount += 1
        return "Local transcript"
    }
    func stopListening() { isListening = false }
}

@MainActor
private final class InputTestOutput: VoiceOutputService {
    func speak(_ text: String) async {}
    func stop() {}
}
