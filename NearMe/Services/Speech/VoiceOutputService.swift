// Adapted from a prior prototype, used with permission.

import AVFoundation

@MainActor
protocol VoiceOutputService: AnyObject {
    var lastVoice: String? { get }
    var onVoiceChanged: ((String) -> Void)? { get set }
    func speak(_ text: String) async
    func prefetch(_ text: String)
    func setSlower(_ slower: Bool)
    func stop()
}

extension VoiceOutputService {
    var lastVoice: String? { nil }
    var onVoiceChanged: ((String) -> Void)? {
        get { nil }
        set {}
    }
    func prefetch(_ text: String) {}
    func setSlower(_ slower: Bool) {}
}

@MainActor
final class SystemVoiceOutputService: NSObject, VoiceOutputService, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private var activeUtterance: AVSpeechUtterance?
    private var watchdog: Task<Void, Never>?
    private var slower = false

    func setSlower(_ slower: Bool) { self.slower = slower }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        stop()

        do {
            try NearMeAudioSession.configureIfNeeded()
        } catch {
            VoiceDiagnostics.log(error)
            return // The caption remains available when audio output cannot start.
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-AU") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slower ? 0.8 : 1)
        utterance.pitchMultiplier = 1.0

        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.activeUtterance = utterance
            synthesizer.speak(utterance)
            // Also release the engine if the OS loses a delegate callback.
            watchdog = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(30, Double(text.count) / 8 + 10))) }
                catch { return }
                guard let self, self.activeUtterance === utterance else { return }
                self.stop()
            }
        }
        // No post-speech deactivation/settle-delay anymore — the session
        // stays active and in `.playAndRecord` for the whole conversation.
    }

    func stop() {
        watchdog?.cancel()
        watchdog = nil
        synthesizer.stopSpeaking(at: .immediate)
        activeUtterance = nil
        continuation?.resume()
        continuation = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard activeUtterance === utterance else { return }
            watchdog?.cancel()
            watchdog = nil
            activeUtterance = nil
            continuation?.resume()
            continuation = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard activeUtterance === utterance else { return }
            watchdog?.cancel()
            watchdog = nil
            activeUtterance = nil
            continuation?.resume()
            continuation = nil
        }
    }
}
