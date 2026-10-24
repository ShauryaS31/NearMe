// Adapted from a prior prototype, used with permission.

import Foundation

@MainActor
final class VoiceInputRouter: VoiceInputService {
    private let elevenLabs: ElevenLabsScribeService
    private let appleFallback: AppleSpeechFallbackService
    private var activeService: VoiceInputService?
    private var listeningGeneration = 0

    init(elevenLabs: ElevenLabsScribeService? = nil,
         appleFallback: AppleSpeechFallbackService? = nil) {
        self.elevenLabs = elevenLabs ?? ElevenLabsScribeService()
        self.appleFallback = appleFallback ?? AppleSpeechFallbackService()
    }

    var isListening: Bool {
        activeService?.isListening ?? false
    }

    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        listeningGeneration += 1
        let generation = listeningGeneration
        if APIKeys.hasElevenLabsKey {
            activeService = elevenLabs
            do {
                return try await elevenLabs.startListening(onPartialTranscript: onPartialTranscript)
            } catch VoiceInputError.noSpeechDetected {
                throw VoiceInputError.noSpeechDetected
            } catch {
                VoiceDiagnostics.log(error)
                guard generation == listeningGeneration else { throw CancellationError() }
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
        listeningGeneration += 1
        activeService?.stopListening()
    }
}
