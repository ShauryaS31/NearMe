import AVFoundation
import Foundation
import Network
import OSLog

@MainActor
protocol VoiceHTTPSession {
    func audio(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: VoiceHTTPSession {
    func audio(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}

@MainActor
final class VoiceConnectivity {
    private let monitor = NWPathMonitor()
    // Unknown connectivity is allowed to try, under the same speech deadline.
    private(set) var isOffline = false

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor in self?.isOffline = offline }
        }
        monitor.start(queue: DispatchQueue(label: "au.nearme.voice.path"))
    }

    deinit { monitor.cancel() }
}

@MainActor
final class ElevenLabsVoiceOutput: VoiceOutputService {
    static let playableAudioDeadline: TimeInterval = 2.5
    static let modelID = "eleven_flash_v2_5"
    private let key: String
    private let voiceID: String
    private let settings: VoiceSettings
    private let session: VoiceHTTPSession
    private let cache: VoiceAudioCache
    private let player: VoiceAudioPlaying
    private let fallback: VoiceOutputService
    private let isOffline: () -> Bool
    private let deadline: TimeInterval
    private var downloads: [String: Task<Data, Error>] = [:]
    private var prefetchTask: Task<Void, Never>?
    private var queuedPrefetch: String?
    private var generation = 0
    private var pendingAudio: CheckedContinuation<AudioOutcome, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var routeObserver: NSObjectProtocol?
    private(set) var lastVoice: String?
    private(set) var lastFallbackReason: String?
    var onVoiceChanged: ((String) -> Void)?

    private enum AudioOutcome { case ready(String), fallback(String), stopped }

    init(key: String = APIKeys.elevenLabsAPIKey, voiceID: String = APIKeys.elevenLabsVoiceID,
         settings: VoiceSettings = VoiceSettings(), session: VoiceHTTPSession = URLSession.shared,
         cache: VoiceAudioCache = VoiceAudioCache(), player: VoiceAudioPlaying = VoiceAudioPlayer(),
         fallback: VoiceOutputService = SystemVoiceOutputService(), isOffline: (() -> Bool)? = nil,
         deadline: TimeInterval = ElevenLabsVoiceOutput.playableAudioDeadline) {
        self.key = key
        self.voiceID = voiceID
        self.settings = settings
        self.session = session
        self.cache = cache
        self.player = player
        self.fallback = fallback
        self.deadline = deadline
        if let isOffline {
            self.isOffline = isOffline
        } else {
            let connectivity = VoiceConnectivity()
            self.isOffline = { connectivity.isOffline }
        }
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor in self?.stop() }
        }
    }

    deinit {
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
    }

    func speak(_ text: String) async {
        stopPlayback()
        let token = generation
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let started = ContinuousClock.now
        let outcome: AudioOutcome
        if let reason = fallbackReason {
            outcome = .fallback(reason)
        } else {
            outcome = await playableAudio(text, token: token)
        }
        guard token == generation, !Task.isCancelled else { return }
        // The preference may have changed while this line was being fetched.
        if !settings.naturalVoiceEnabled {
            player.stop()
            await speakSystem(text, reason: "natural voice off", started: started)
            return
        }
        switch outcome {
        case .ready(let source):
            lastVoice = "ElevenLabs"
            lastFallbackReason = nil
            onVoiceChanged?("ElevenLabs")
            log(text, source: source, reason: "none", started: started)
            let success = await player.play()
            if !success, token == generation {
                await speakSystem(text, reason: "audio playback failed", started: started)
            }
        case .fallback(let reason):
            await speakSystem(text, reason: reason, started: started)
        case .stopped: break
        }
    }

    func prefetch(_ text: String) {
        guard fallbackReason == nil else { return }
        let cacheKey = cacheKey(text)
        guard cache.audio(for: cacheKey) == nil else { return }
        guard prefetchTask == nil else { queuedPrefetch = text; return }
        let download = download(text, cacheKey: cacheKey)
        prefetchTask = Task { [weak self] in
            _ = try? await download.value
            guard let self else { return }
            self.prefetchTask = nil
            if let next = self.queuedPrefetch {
                self.queuedPrefetch = nil
                self.prefetch(next)
            }
        }
    }

    func stop() {
        queuedPrefetch = nil
        stopPlayback()
        // Downloads may still populate the cache, but never start playback.
    }

    func setSlower(_ slower: Bool) {
        player.rate = slower ? 0.8 : 1
        fallback.setSlower(slower)
    }

    private func stopPlayback() {
        generation += 1
        resolveAudio(.stopped)
        player.stop()
        fallback.stop()
    }

    private var fallbackReason: String? {
        if !settings.naturalVoiceEnabled { return "natural voice off" }
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "empty key" }
        if voiceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "empty voice id" }
        if isOffline() { return "offline" }
        return nil
    }

    private func cacheKey(_ text: String) -> String {
        VoiceAudioCache.key(voiceID: voiceID, modelID: Self.modelID, text: text)
    }

    private func playableAudio(_ text: String, token: Int) async -> AudioOutcome {
        let cacheKey = cacheKey(text)
        let cutoff = ContinuousClock.now.advanced(by: .seconds(deadline))
        if let data = cache.audio(for: cacheKey) {
            do {
                try player.prepare(data)
                guard ContinuousClock.now < cutoff else { player.stop(); return .fallback("timeout") }
                return .ready("ElevenLabs cache hit")
            } catch {
                cache.remove(cacheKey)
                return .fallback("audio decode failed")
            }
        }
        let download = download(text, cacheKey: cacheKey)
        return await withCheckedContinuation { continuation in
            pendingAudio = continuation
            deadlineTask = Task { [weak self] in
                do { try await ContinuousClock().sleep(until: cutoff) } catch { return }
                guard let self, token == self.generation else { return }
                self.resolveAudio(.fallback("timeout"))
            }
            Task { [weak self] in
                do {
                    let data = try await download.value
                    guard let self, token == self.generation, self.pendingAudio != nil else { return }
                    guard ContinuousClock.now < cutoff else { self.resolveAudio(.fallback("timeout")); return }
                    do { try self.player.prepare(data) }
                    catch {
                        self.cache.remove(cacheKey)
                        self.resolveAudio(.fallback("audio decode failed"))
                        return
                    }
                    guard ContinuousClock.now < cutoff else {
                        self.player.stop()
                        self.resolveAudio(.fallback("timeout"))
                        return
                    }
                    self.resolveAudio(.ready("ElevenLabs network"))
                } catch {
                    guard let self, token == self.generation, self.pendingAudio != nil else { return }
                    let reason: String
                    if case VoicePlaybackError.http(let status) = error { reason = "HTTP \(status)" }
                    else { reason = "request failed" }
                    self.resolveAudio(.fallback(reason))
                }
            }
        }
    }

    private func resolveAudio(_ outcome: AudioOutcome) {
        deadlineTask?.cancel()
        deadlineTask = nil
        let pending = pendingAudio
        pendingAudio = nil
        pending?.resume(returning: outcome)
    }

    private func download(_ text: String, cacheKey: String) -> Task<Data, Error> {
        if let existing = downloads[cacheKey] { return existing }
        let task = Task { [self] in
            defer { downloads[cacheKey] = nil }
            guard settings.naturalVoiceEnabled else { throw VoicePlaybackError.request }
            guard let baseURL = URL(string: "https://api.elevenlabs.io/v1/text-to-speech") else { throw VoicePlaybackError.request }
            var components = URLComponents(url: baseURL.appendingPathComponent(voiceID), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "output_format", value: "mp3_44100_128")]
            guard let url = components?.url else { throw VoicePlaybackError.request }
            var request = URLRequest(url: url, timeoutInterval: 30)
            request.httpMethod = "POST"
            request.setValue(key, forHTTPHeaderField: "xi-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
            request.httpBody = try JSONEncoder().encode(SpeechBody(text: text, model_id: Self.modelID))
            let (data, response) = try await session.audio(for: request)
            guard let response = response as? HTTPURLResponse else { throw VoicePlaybackError.request }
            guard (200..<300).contains(response.statusCode) else { throw VoicePlaybackError.http(response.statusCode) }
            cache.store(data, for: cacheKey)
            return data
        }
        downloads[cacheKey] = task
        return task
    }

    private struct SpeechBody: Encodable { let text: String; let model_id: String }

    private func speakSystem(_ text: String, reason: String, started: ContinuousClock.Instant) async {
        lastVoice = "System voice"
        lastFallbackReason = reason
        onVoiceChanged?("System voice")
        log(text, source: "System voice", reason: reason, started: started)
        await fallback.speak(text)
    }

    private func log(_ text: String, source: String, reason: String, started: ContinuousClock.Instant) {
        let elapsed = started.duration(to: .now).components
        let ms = elapsed.seconds * 1000 + elapsed.attoseconds / 1_000_000_000_000_000
        VoiceDiagnostics.logger.info("Voice=\(source, privacy: .public) reason=\(reason, privacy: .public) ms=\(ms) line=\(text, privacy: .private)")
    }
}
