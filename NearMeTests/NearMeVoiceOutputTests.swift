import Foundation
import XCTest
@testable import NearMe

@MainActor
final class NearMeVoiceOutputTests: XCTestCase {
    func testOrdinaryVoiceCannotSelectCloudFromLegacyPreferences() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "naturalVoiceEnabled")
        defer {
            if let previous { defaults.set(previous, forKey: "naturalVoiceEnabled") }
            else { defaults.removeObject(forKey: "naturalVoiceEnabled") }
        }

        // Both production consumers use this factory. A migrated true value must
        // not restore the old ElevenLabs provider, including its eager prefetch.
        for enabled in [true, false] {
            defaults.set(enabled, forKey: "naturalVoiceEnabled")
            XCTAssertEqual(VoiceSettings().naturalVoiceEnabled, enabled)
            let output = NearMeVoiceOutput.make(demoFamilyVoice: false)
            XCTAssertTrue(output is SystemVoiceOutputService,
                          "Ordinary speech must stay local regardless of legacy preferences or build credentials")
            output.stop()
        }
        defaults.removeObject(forKey: "naturalVoiceEnabled")
        XCTAssertTrue(NearMeVoiceOutput.make(demoFamilyVoice: false) is SystemVoiceOutputService)
    }

    func testOrdinaryPrefetchDoesNotStartPlayback() async {
        let output = NearMeVoiceOutput.make(demoFamilyVoice: false)
        XCTAssertTrue(output is SystemVoiceOutputService)
        var playbackStarted = false
        output.onPlaybackStarted = { playbackStarted = true }
        // Exercise existential protocol dispatch, as the engine does for its
        // acknowledgement and next practice caption. System prefetch is a no-op.
        output.prefetch("Sure, let me help you with that.")
        output.prefetch("Choose your destination.")
        for _ in 0..<10 { await Task.yield() }
        XCTAssertFalse(playbackStarted)
        output.stop()
        // No HTTP session, credentials or cloud provider exists in this output.
        // Device offline/audio and network inspection are separate Mac gates.
    }

    func testOnlyExplicitDemoBuildFlagSelectsFamilyVoice() {
        for disabled in ["", "NO", "true", "1", "$(NEARME_DEMO_FAMILY_VOICE)"] {
            XCTAssertFalse(APIKeys.isDemoFamilyVoiceEnabled(disabled))
        }
        XCTAssertTrue(APIKeys.isDemoFamilyVoiceEnabled(" YES "))
        let demo = NearMeVoiceOutput.make(demoFamilyVoice: true)
        XCTAssertTrue(demo is ElevenLabsVoiceOutput)
        demo.stop()
        let configured = NearMeVoiceOutput.make()
        XCTAssertEqual(configured is ElevenLabsVoiceOutput, APIKeys.demoFamilyVoiceEnabled)
        configured.stop()
    }
}
