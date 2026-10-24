// Adapted from a prior prototype, used with permission.

import Foundation
import OSLog

nonisolated enum VoiceDiagnostics {
    static let logger = Logger(subsystem: "au.nearme.ios", category: "voice")

    static func log(_ error: Error) {
        let nsError = error as NSError
        logger.error("Voice error type=\(String(reflecting: type(of: error)), privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) description=\(nsError.localizedDescription, privacy: .private)")
        if let inputError = error as? VoiceInputError {
            switch inputError {
            case .network(let underlying), .audioEngineFailed(let underlying): log(underlying)
            default: break
            }
        }
    }

    static func message(for error: Error) -> String {
        var message: String
        if let inputError = error as? VoiceInputError {
            switch inputError {
            case .microphonePermissionDenied:
                message = "Allow NearMe to use the microphone in Settings > Privacy & Security > Microphone. You can type instead."
            case .speechPermissionDenied:
                message = "Allow NearMe to use speech recognition in Settings > Privacy & Security > Speech Recognition. You can type instead."
            case .microphoneUnavailable, .audioEngineFailed:
                message = "NearMe can't hear the microphone right now"
            case .recognizerUnavailable:
                message = "Speech recognition isn't available right now. You can type instead."
            case .unsupportedOnDeviceLocale:
                return "Speech recognition on this phone isn't available for your language yet. You can type instead."
            case .noSpeechDetected:
                message = "I didn't catch that. Please try again or type instead."
            default:
                message = "NearMe couldn't hear your request. Please try again or type instead."
            }
        } else {
            message = "NearMe couldn't hear your request. Please try again or type instead."
        }
        #if DEBUG
        var detail = error as NSError
        if let inputError = error as? VoiceInputError {
            switch inputError {
            case .network(let underlying), .audioEngineFailed(let underlying): detail = underlying as NSError
            default: break
            }
        }
        message += " (\(detail.domain), \(detail.code))"
        #endif
        return message
    }
}

nonisolated enum VoiceInputError: Error, LocalizedError {
    case microphonePermissionDenied
    case speechPermissionDenied
    case microphoneUnavailable
    case recognizerUnavailable
    case unsupportedOnDeviceLocale
    case audioEngineFailed(Error)
    case noSpeechDetected
    case network(Error)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied: return "Microphone permission denied."
        case .speechPermissionDenied: return "Speech recognition permission denied."
        case .recognizerUnavailable: return "Speech recognizer unavailable."
        case .unsupportedOnDeviceLocale: return "On-device speech unavailable for this locale."
        case .audioEngineFailed(let error): return "Audio engine failed: \(error.localizedDescription)"
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
    func prepareForListening() async throws

    /// Starts listening and returns the final transcript once the user
    /// stops talking (silence timeout) or `stopListening()` is called.
    /// `onPartialTranscript` is invoked repeatedly as interim text becomes
    /// available, so the UI can optionally show live captions.
    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String

    /// Ends listening early (e.g. the user tapped "cancel").
    func stopListening()
}

extension VoiceInputService {
    func prepareForListening() async throws {}
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
