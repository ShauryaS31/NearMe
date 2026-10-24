import AVFoundation
import Combine
import Foundation
import OSLog
import Speech
import UIKit

/// Only this lock-protected gate is touched by the real-time input callback.
/// Pausing clears the request before cancelling recognition; no paused audio is queued.
nonisolated final class CommandAudioGate: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var otherAudioDeadline: TimeInterval?

    func setOtherAudioAllowed(_ allowed: Bool) {
        lock.lock()
        defer { lock.unlock() }
        otherAudioDeadline = allowed ? ProcessInfo.processInfo.systemUptime + 8 : nil
    }

    func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        defer { lock.unlock() }
        self.request = request
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let request else { return }
        let session = AVAudioSession.sharedInstance()
        let windowOpen = otherAudioDeadline.map { ProcessInfo.processInfo.systemUptime < $0 } ?? false
        guard windowOpen || (!session.secondaryAudioShouldBeSilencedHint && !session.isOtherAudioPlaying) else { return }
        request.append(buffer)
    }
}

@MainActor
final class OnDeviceCommandSpeechInput: CommandSpeechInput {
    var allowsOtherAudio = false { didSet { gate.setOtherAudioAllowed(allowsOtherAudio) } }
    var onResult: ((String, Bool) -> Void)?
    var onFailure: (() -> Void)?
    var onCaptureLost: (() -> Void)?
    var onAudioHint: (() -> Void)?
    var otherAudio: Bool {
        let session = AVAudioSession.sharedInstance()
        return session.secondaryAudioShouldBeSilencedHint || session.isOtherAudioPlaying
    }
    private let engine = AVAudioEngine()
    private let gate = CommandAudioGate()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var generation = 0
    private var installedTap = false
    private var ownsSession = false
    private var observations: Set<AnyCancellable> = []

    init() {
        NotificationCenter.default.publisher(for: AVAudioSession.silenceSecondaryAudioHintNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.onAudioHint?() }
            }.store(in: &observations)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.ownsSession else { return }
                    self.pauseRecognition()
                    self.onCaptureLost?()
                }
            }.store(in: &observations)
    }

    func startCapture() throws {
        guard UIApplication.shared.applicationState == .active else { throw VoiceInputError.microphoneUnavailable }
        guard AVAudioApplication.shared.recordPermission == .granted else { throw VoiceInputError.microphonePermissionDenied }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw VoiceInputError.speechPermissionDenied }
        let locales = [Locale(identifier: "en-AU"), Locale.current]
        recognizer = locales.compactMap { SFSpeechRecognizer(locale: $0) }.first {
            $0.supportsOnDeviceRecognition && $0.isAvailable
        }
        guard recognizer != nil else { throw VoiceInputError.unsupportedOnDeviceLocale }
        do {
            ownsSession = true
            try NearMeAudioSession.setCommandListeningActive(true)
            do { try engine.inputNode.setVoiceProcessingEnabled(true) }
            catch { VoiceDiagnostics.logger.notice("Command input voice processing unavailable") }
            // Use the minimum supported voice-processing attenuation. Session
            // duckOthers is independently scoped to actual NearMe playback.
            var ducking = AVAudioVoiceProcessingOtherAudioDuckingConfiguration()
            ducking.enableAdvancedDucking = false
            ducking.duckingLevel = .min
            engine.inputNode.voiceProcessingOtherAudioDuckingConfiguration = ducking
            let enabled = engine.inputNode.isVoiceProcessingEnabled
            VoiceDiagnostics.logger.info("Command input voice processing=\(enabled, privacy: .public)")
            let format = engine.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw VoiceInputError.microphoneUnavailable }
            let gate = self.gate
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in gate.append(buffer) }
            installedTap = true
            engine.prepare()
            try engine.start()
        } catch {
            stopCapture()
            throw error
        }
    }

    static func makeRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.contextualStrings = VoiceCommand.recognitionPhrases
        return request
    }

    func startRecognition() throws {
        pauseRecognition()
        // An interruption can stop the hardware engine. Recovery requires a foreground tap.
        guard engine.isRunning, let recognizer, recognizer.isAvailable else { throw VoiceInputError.recognizerUnavailable }
        let token = generation
        let request = Self.makeRequest()
        self.request = request
        recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal == true
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if let text { self.onResult?(text, final) }
                guard self.generation == token else { return }
                if failed { self.onFailure?() }
            }
        }
        gate.set(request)
    }

    func pauseRecognition() {
        gate.set(nil)
        generation += 1
        request?.endAudio()
        request = nil
        recognition?.cancel()
        recognition = nil
    }

    func stopCapture() {
        allowsOtherAudio = false
        pauseRecognition()
        engine.stop()
        if installedTap { engine.inputNode.removeTap(onBus: 0); installedTap = false }
        if ownsSession {
            ownsSession = false
            try? NearMeAudioSession.setCommandListeningActive(false)
        }
    }
}
