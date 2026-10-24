// Adapted from a prior prototype, used with permission.

import AVFoundation
import Speech
import Combine

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var microphoneAuthorized = false
    @Published private(set) var speechRecognitionAuthorized = false

    var isFullyAuthorized: Bool {
        microphoneAuthorized && speechRecognitionAuthorized
    }

    /// Requests both permissions in sequence. Safe to call more than once —
    /// iOS only shows the system prompt the first time; afterwards this just
    /// reports back the user's earlier decision from Settings.
    func requestAll() async {
        microphoneAuthorized = await requestMicrophone()
        speechRecognitionAuthorized = await requestSpeechRecognition()
    }

    private func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                continuation.resume(returning: true)
            case .denied:
                continuation.resume(returning: false)
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }

    private func requestSpeechRecognition() async -> Bool {
        await withCheckedContinuation { continuation in
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized:
                continuation.resume(returning: true)
            case .denied, .restricted:
                continuation.resume(returning: false)
            case .notDetermined:
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
}
