import XCTest
@testable import NearMe

final class VoiceDiagnosticsTests: XCTestCase {
    func testKnownErrorsHaveActionableMessages() {
        XCTAssertTrue(VoiceDiagnostics.message(for: VoiceInputError.microphonePermissionDenied).contains("Settings > Privacy & Security > Microphone"))
        XCTAssertTrue(VoiceDiagnostics.message(for: VoiceInputError.speechPermissionDenied).contains("Settings > Privacy & Security > Speech Recognition"))
        XCTAssertTrue(VoiceDiagnostics.message(for: VoiceInputError.microphoneUnavailable).hasPrefix("NearMe can't hear the microphone right now"))
        XCTAssertTrue(VoiceDiagnostics.message(for: VoiceInputError.recognizerUnavailable).hasPrefix("Speech recognition isn't available right now. You can type instead."))
    }

    func testAudioEngineFailurePreservesUnderlyingDomainAndCodeOnlyInDebug() {
        let error = NSError(domain: "TestAudioEngine", code: -123, userInfo: [NSLocalizedDescriptionKey: "Technical detail"])
        let message = VoiceDiagnostics.message(for: VoiceInputError.audioEngineFailed(error))
        XCTAssertTrue(message.hasPrefix("NearMe can't hear the microphone right now"))
        XCTAssertFalse(message.contains("Technical detail"))
        #if DEBUG
        XCTAssertTrue(message.contains("TestAudioEngine, -123"))
        #else
        XCTAssertFalse(message.contains("TestAudioEngine"))
        #endif
    }

    func testUnknownErrorKeepsPlainMessage() {
        let error = NSError(domain: "UnknownVoiceError", code: 42, userInfo: [NSLocalizedDescriptionKey: "Technical detail"])
        let message = VoiceDiagnostics.message(for: error)
        XCTAssertTrue(message.hasPrefix("NearMe couldn't hear your request. Please try again or type instead."))
        XCTAssertFalse(message.contains("Technical detail"))
    }
}
