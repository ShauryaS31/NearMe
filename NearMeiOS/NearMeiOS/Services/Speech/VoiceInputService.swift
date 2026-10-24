// Adapted from a prior prototype, used with permission.

import Foundation

enum VoiceInputError: Error, LocalizedError {
    case microphoneUnavailable
    case noSpeechDetected
    case network(Error)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphoneUnavailable:
            return "NearMe couldn't access the microphone."
        case .noSpeechDetected:
            return "I didn't catch that — could you say it again?"
        case .network(let error):
            return "Network error while transcribing: \(error.localizedDescription)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

@MainActor
protocol VoiceInputService: AnyObject {
    /// True while actively recording/listening.
    var isListening: Bool { get }

    /// Starts listening and returns the final transcript once the user
    /// stops talking (silence timeout) or `stopListening()` is called.
    /// `onPartialTranscript` is invoked repeatedly as interim text becomes
    /// available, so the UI can optionally show live captions.
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String

    /// Ends listening early (e.g. the user tapped "cancel").
    func stopListening()
}

final class ResumeOnce<T>: @unchecked Sendable {
    private let continuation: CheckedContinuation<T, Error>
    private let lock = NSLock()
    private var didResume = false

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func fulfill(returning value: T) {
        lock.lock()
        let alreadyResumed = didResume
        didResume = true
        lock.unlock()
        guard !alreadyResumed else { return }
        continuation.resume(returning: value)
    }

    func fulfill(throwing error: Error) {
        lock.lock()
        let alreadyResumed = didResume
        didResume = true
        lock.unlock()
        guard !alreadyResumed else { return }
        continuation.resume(throwing: error)
    }
}
