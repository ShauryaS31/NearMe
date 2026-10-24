// Adapted from a prior prototype, used with permission.

import Foundation

@MainActor
final class VoiceInputRouter: VoiceInputService {
    private let elevenLabs: ElevenLabsScribeService
    private let appleFallback: AppleSpeechFallbackService
    private var activeService: VoiceInputService?

    init(elevenLabs: ElevenLabsScribeService? = nil,
         appleFallback: AppleSpeechFallbackService? = nil) {
        self.elevenLabs = elevenLabs ?? ElevenLabsScribeService()
        self.appleFallback = appleFallback ?? AppleSpeechFallbackService()
    }

    var isListening: Bool {
        activeService?.isListening ?? false
    }

    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        if APIKeys.hasElevenLabsKey {
            activeService = elevenLabs
            do {
                return try await elevenLabs.startListening(onPartialTranscript: onPartialTranscript)
            } catch VoiceInputError.noSpeechDetected {
                throw VoiceInputError.noSpeechDetected
            } catch {
                // Network hiccup, bad key, etc. — fall back rather than fail the session.
                activeService = appleFallback
                return try await appleFallback.startListening(onPartialTranscript: onPartialTranscript)
            }
        } else {
            activeService = appleFallback
            return try await appleFallback.startListening(onPartialTranscript: onPartialTranscript)
        }
    }

    func stopListening() {
        activeService?.stopListening()
    }
}
