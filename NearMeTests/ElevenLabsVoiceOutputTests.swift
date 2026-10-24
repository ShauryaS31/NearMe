import Foundation
import XCTest
@testable import NearMe

@MainActor
final class ElevenLabsVoiceOutputTests: XCTestCase {
    func testCacheKeyUsesVoiceModelAndExactText() {
        let key = VoiceAudioCache.key(voiceID: "test-voice", modelID: ElevenLabsVoiceOutput.modelID, text: "Hello")
        XCTAssertEqual(key, "4ee7c9676f5a5696daae822c2fde5196d3a288892af1d5ba91f161a306050404")
        XCTAssertNotEqual(key, VoiceAudioCache.key(voiceID: "another-test-voice", modelID: ElevenLabsVoiceOutput.modelID, text: "Hello"))
        XCTAssertNotEqual(key, VoiceAudioCache.key(voiceID: "test-voice", modelID: "another-model", text: "Hello"))
        XCTAssertNotEqual(key, VoiceAudioCache.key(voiceID: "test-voice", modelID: ElevenLabsVoiceOutput.modelID, text: "hello"))
    }

    func testNetworkContractAndPersistentCacheHit() async throws {
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        let output = fixture.output()
        await output.speak("Hello")
        XCTAssertEqual(output.lastVoice, "ElevenLabs")
        XCTAssertNil(output.lastFallbackReason)
        let request = try XCTUnwrap(fixture.session.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.elevenlabs.io/v1/text-to-speech/test-voice?output_format=mp3_44100_128")
        XCTAssertEqual(request.value(forHTTPHeaderField: "xi-api-key"), "test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "audio/mpeg")
        let body = try JSONDecoder().decode([String: String].self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(body, ["text": "Hello", "model_id": "eleven_flash_v2_5"])

        let secondOutput = fixture.output(cache: VoiceAudioCache(directory: fixture.directory))
        await secondOutput.speak("Hello")
        XCTAssertEqual(fixture.session.requests.count, 1)
        XCTAssertEqual(fixture.player.playCount, 2)
        XCTAssertEqual(fixture.player.prepared, [fixture.session.data, fixture.session.data])
        XCTAssertEqual(secondOutput.lastVoice, "ElevenLabs")
    }

    func testMissingConfigurationOfflineAndSettingSkipAllRequests() async throws {
        for (key, voiceID, offline, enabled, reason) in [
            ("", "test-voice", false, true, "empty key"),
            ("test-key", "", false, true, "empty voice id"),
            ("test-key", "test-voice", true, true, "offline"),
            ("test-key", "test-voice", false, false, "natural voice off")
        ] {
            let fixture = try VoiceFixture()
            defer { fixture.cleanUp() }
            fixture.settings.naturalVoiceEnabled = enabled
            let output = fixture.output(key: key, voiceID: voiceID, offline: offline)
            output.prefetch("Next")
            await output.speak("Hello")
            XCTAssertEqual(output.lastVoice, "System voice")
            XCTAssertEqual(output.lastFallbackReason, reason)
            XCTAssertEqual(fixture.system.lines, ["Hello"])
            XCTAssertTrue(fixture.session.requests.isEmpty)
            XCTAssertEqual(fixture.player.playCount, 0)
        }
    }

    func testHTTPAndRequestFailuresUseSystemVoice() async throws {
        for status in [401, 500] {
            let fixture = try VoiceFixture()
            defer { fixture.cleanUp() }
            fixture.session.status = status
            let output = fixture.output()
            await output.speak("Hello")
            XCTAssertEqual(output.lastFallbackReason, "HTTP \(status)")
            XCTAssertEqual(fixture.system.lines, ["Hello"])
            XCTAssertNil(fixture.cache.audio(for: fixture.cacheKey("Hello")))
        }
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        fixture.session.error = URLError(.notConnectedToInternet)
        let output = fixture.output()
        await output.speak("Hello")
        XCTAssertEqual(output.lastFallbackReason, "request failed")
        XCTAssertEqual(fixture.system.lines, ["Hello"])
    }

    func testDecodeAndPlaybackFailuresUseSystemVoice() async throws {
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        fixture.player.rejectData = true
        let output = fixture.output()
        await output.speak("Hello")
        XCTAssertEqual(output.lastFallbackReason, "audio decode failed")
        XCTAssertNil(fixture.cache.audio(for: fixture.cacheKey("Hello")))
        fixture.player.rejectData = false
        fixture.player.playSucceeds = false
        await output.speak("Next")
        XCTAssertEqual(output.lastFallbackReason, "audio playback failed")
        XCTAssertEqual(fixture.system.lines, ["Hello", "Next"])
    }

    func testTimeoutReturnsBeforeNetworkAndLateResponseIsOnlyCached() async throws {
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        fixture.session.suspend = true
        let output = fixture.output(deadline: 0.01)
        let returned = expectation(description: "Fallback returns without waiting for network")
        let speech = Task { await output.speak("Late"); returned.fulfill() }
        await fulfillment(of: [returned], timeout: 1)
        XCTAssertEqual(output.lastFallbackReason, "timeout")
        XCTAssertEqual(fixture.system.lines, ["Late"])
        XCTAssertEqual(fixture.player.playCount, 0)
        fixture.session.release()
        await speech.value
        await eventually { fixture.cache.audio(for: fixture.cacheKey("Late")) != nil }
        XCTAssertEqual(fixture.player.playCount, 0)
        await output.speak("Late")
        XCTAssertEqual(fixture.session.requests.count, 1)
        XCTAssertEqual(fixture.player.playCount, 1)
    }

    func testStopDuringRequestPreventsLateSpeech() async throws {
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        fixture.session.suspend = true
        let output = fixture.output()
        let speech = Task { await output.speak("Stopped") }
        await eventually { fixture.session.pending != nil }
        output.stop()
        await speech.value
        fixture.session.release()
        await eventually { fixture.cache.audio(for: fixture.cacheKey("Stopped")) != nil }
        XCTAssertTrue(fixture.system.lines.isEmpty)
        XCTAssertEqual(fixture.player.playCount, 0)
    }

    func testSpeakWaitsForPlaybackAndStopReleasesIt() async throws {
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        fixture.player.suspend = true
        let output = fixture.output()
        var returned = false
        let speech = Task { await output.speak("Hello"); returned = true }
        await eventually { fixture.player.pending != nil }
        XCTAssertFalse(returned)
        fixture.player.finish(true)
        await speech.value
        XCTAssertTrue(returned)

        let second = Task { await output.speak("Again") }
        await eventually { fixture.player.pending != nil }
        output.stop()
        await second.value
        XCTAssertTrue(fixture.system.lines.isEmpty)
    }

    func testPrefetchIsSingleFlightSilentAndReusedBySpeak() async throws {
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        fixture.session.suspend = true
        let output = fixture.output()
        output.prefetch("Next")
        output.prefetch("Next")
        await eventually { fixture.session.pending != nil }
        XCTAssertEqual(fixture.session.requests.count, 1)
        let speech = Task { await output.speak("Next") }
        fixture.session.release()
        await speech.value
        XCTAssertEqual(fixture.session.requests.count, 1)
        XCTAssertEqual(fixture.player.playCount, 1)
        XCTAssertTrue(fixture.system.lines.isEmpty)

        fixture.session.suspend = false
        fixture.session.status = 500
        await Task.yield()
        output.prefetch("Failed prefetch")
        await eventually { fixture.session.requests.count == 2 }
        XCTAssertTrue(fixture.system.lines.isEmpty)
        XCTAssertEqual(fixture.player.playCount, 1)
    }

    func testNaturalVoiceOffAlsoSkipsCachedAudio() async throws {
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        XCTAssertTrue(fixture.settings.naturalVoiceEnabled)
        fixture.cache.store(fixture.session.data, for: fixture.cacheKey("Hello"))
        fixture.settings.naturalVoiceEnabled = false
        XCTAssertFalse(VoiceSettings(defaults: fixture.defaults).naturalVoiceEnabled)
        let output = fixture.output()
        await output.speak("Hello")
        output.prefetch("Next")
        XCTAssertEqual(output.lastFallbackReason, "natural voice off")
        XCTAssertEqual(fixture.player.playCount, 0)
        XCTAssertTrue(fixture.session.requests.isEmpty)
    }

    func testSlowerReusesCachedAudioAndConfiguresSystemFallback() async throws {
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        let output = fixture.output()
        await output.speak("Hello")
        output.setSlower(true)
        await output.speak("Hello")
        XCTAssertEqual(fixture.player.rate, 0.8)
        XCTAssertTrue(fixture.system.slower)
        XCTAssertEqual(fixture.session.requests.count, 1)
        output.setSlower(false)
        XCTAssertEqual(fixture.player.rate, 1)
        XCTAssertFalse(fixture.system.slower)
    }

    func testCacheEvictsOldestAndEnforcesByteLimit() throws {
        let fixture = try VoiceFixture()
        defer { fixture.cleanUp() }
        let cache = VoiceAudioCache(directory: fixture.directory, fileLimit: 2, byteLimit: 6)
        cache.store(Data([1, 2]), for: "first")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)],
                                             ofItemAtPath: fixture.directory.appendingPathComponent("first.mp3").path)
        cache.store(Data([3, 4]), for: "second")
        cache.store(Data([5, 6]), for: "third")
        XCTAssertNil(cache.audio(for: "first"))
        XCTAssertNotNil(cache.audio(for: "second"))
        XCTAssertNotNil(cache.audio(for: "third"))
        cache.store(Data(repeating: 0, count: 6), for: "large")
        XCTAssertNil(cache.audio(for: "second"))
        XCTAssertNil(cache.audio(for: "third"))
        XCTAssertEqual(cache.audio(for: "large")?.count, 6)
        cache.store(Data(repeating: 0, count: 7), for: "too-large")
        XCTAssertNil(cache.audio(for: "too-large"))
    }

    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Asynchronous operation did not finish", file: file, line: line)
    }
}

@MainActor
private final class VoiceFixture {
    let suite = "NearMeVoiceTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let settings: VoiceSettings
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let cache: VoiceAudioCache
    let session = StubVoiceSession()
    let player = StubVoicePlayer()
    let system = StubSystemVoice()

    init() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        self.defaults = defaults
        settings = VoiceSettings(defaults: defaults)
        cache = VoiceAudioCache(directory: directory)
    }

    func output(key: String = "test-key", voiceID: String = "test-voice", offline: Bool = false,
                deadline: TimeInterval = ElevenLabsVoiceOutput.playableAudioDeadline, cache: VoiceAudioCache? = nil) -> ElevenLabsVoiceOutput {
        ElevenLabsVoiceOutput(key: key, voiceID: voiceID, settings: settings, session: session,
                             cache: cache ?? self.cache, player: player, fallback: system,
                             isOffline: { offline }, deadline: deadline)
    }

    func cacheKey(_ text: String) -> String {
        VoiceAudioCache.key(voiceID: "test-voice", modelID: ElevenLabsVoiceOutput.modelID, text: text)
    }

    func cleanUp() {
        session.release()
        player.stop()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private final class StubVoiceSession: VoiceHTTPSession {
    var requests: [URLRequest] = []
    var status = 200
    var data = Data("fake decoded by player stub".utf8)
    var error: Error?
    var suspend = false
    var pending: CheckedContinuation<Void, Never>?

    func audio(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if suspend { await withCheckedContinuation { pending = $0 } }
        if let error { throw error }
        let url = try XCTUnwrap(request.url)
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
        return (data, response)
    }

    func release() { let continuation = pending; pending = nil; continuation?.resume() }
}

@MainActor
private final class StubVoicePlayer: VoiceAudioPlaying {
    var rate: Float = 1
    var prepared: [Data] = []
    var playCount = 0
    var rejectData = false
    var playSucceeds = true
    var suspend = false
    var pending: CheckedContinuation<Bool, Never>?

    func prepare(_ data: Data) throws {
        if rejectData { throw VoicePlaybackError.decode }
        prepared.append(data)
    }
    func play() async -> Bool {
        playCount += 1
        if suspend { return await withCheckedContinuation { pending = $0 } }
        return playSucceeds
    }
    func finish(_ success: Bool) { let continuation = pending; pending = nil; continuation?.resume(returning: success) }
    func stop() { finish(false) }
}

@MainActor
private final class StubSystemVoice: VoiceOutputService {
    var lines: [String] = []
    var slower = false
    func setSlower(_ slower: Bool) { self.slower = slower }
    func speak(_ text: String) async { lines.append(text) }
    func stop() {}
}
