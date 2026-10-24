// Adapted from a prior prototype, used with permission.

import AVFoundation

@MainActor
protocol VoiceOutputService: AnyObject {
    func speak(_ text: String) async
    func stop()
}

@MainActor
final class SystemVoiceOutputService: NSObject, VoiceOutputService, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private var activeUtterance: AVSpeechUtterance?

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
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.activeUtterance = utterance
            synthesizer.speak(utterance)
        }
        // No post-speech deactivation/settle-delay anymore — the session
        // stays active and in `.playAndRecord` for the whole conversation.
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        activeUtterance = nil
        continuation?.resume()
        continuation = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard activeUtterance === utterance else { return }
            activeUtterance = nil
            continuation?.resume()
            continuation = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard activeUtterance === utterance else { return }
            activeUtterance = nil
            continuation?.resume()
            continuation = nil
        }
    }
}
