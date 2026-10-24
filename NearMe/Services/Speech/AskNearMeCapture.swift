import AVFoundation
import Combine
import Foundation
import Speech
import UIKit

/// Audio-hint notifications aren't sufficient while the app is backgrounded.
/// Poll only during the explicitly active microphone session, emitting transitions.
@MainActor final class AskMediaMonitor {
    private let read: () -> Bool
    private let changed: (Bool) -> Void
    private let sleep: () async throws -> Void
    private var task: Task<Void, Never>?
    private var previous: Bool?
    private var active = false

    init(read: @escaping () -> Bool, changed: @escaping (Bool) -> Void,
         sleep: (() async throws -> Void)? = nil) {
        self.read = read; self.changed = changed
        self.sleep = sleep ?? { try await Task.sleep(for: .milliseconds(500)) }
    }

    func start() {
        stop()
        active = true; previous = read()
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do { try await self.sleep() } catch { return }
                guard !Task.isCancelled else { return }
                self.check()
            }
        }
    }

    func check() {
        guard active else { return }
        let value = read()
        guard value != previous else { return }
        previous = value
        changed(value)
    }

    func stop() {
        active = false; previous = nil
        task?.cancel(); task = nil
    }
}

/// One hardware activation per explicit widget session. Paused recognition drops
/// buffers immediately rather than queuing NearMe's voice for the next request.
@MainActor final class AskNearMeCapture: AskCapturing {
    var onResult: ((String) -> Void)?
    var onFailure: (() -> Void)?
    var onSpeech: (() -> Void)?
    var onMediaChanged: (() -> Void)?
    var onRecognitionEnded: (() -> Void)?
    var otherAudio: Bool {
        let audio = AVAudioSession.sharedInstance()
        return audio.isOtherAudioPlaying || audio.secondaryAudioShouldBeSilencedHint
    }
    private let engine = AVAudioEngine()
    private let gate = CommandAudioGate()
    private var recognition: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer?
    private var transcript = ""
    private var token = UUID()
    private var tapped = false
    private var ownsAudio = false
    private var endpoint: Task<Void, Never>?
    private var utteranceLimit: Task<Void, Never>?
    private var observations: Set<AnyCancellable> = []
    private lazy var mediaMonitor = AskMediaMonitor(read: { [weak self] in self?.otherAudio ?? false },
        changed: { [weak self] playing in
            guard let self, self.ownsAudio else { return }
            if playing { self.pauseRecognition() }
            self.onMediaChanged?()
        })

    static func availableRecognizer() -> SFSpeechRecognizer? {
        // The dialog/command policy is English. Never silently choose another language.
        [Locale(identifier: "en-AU"), Locale(identifier: "en-US")]
            .compactMap { SFSpeechRecognizer(locale: $0) }
            .first { $0.isAvailable && $0.supportsOnDeviceRecognition }
    }

    nonisolated static func isRouteLoss(_ raw: UInt?) -> Bool {
        raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            || raw == AVAudioSession.RouteChangeReason.noSuitableRouteForCategory.rawValue
    }

    init() {
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                     AVAudioSession.mediaServicesWereResetNotification, UIApplication.didBecomeActiveNotification] {
            NotificationCenter.default.publisher(for: name).sink { [weak self] notification in
                let relevant: Bool
                if notification.name == AVAudioSession.routeChangeNotification {
                    relevant = Self.isRouteLoss(notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                } else if notification.name == AVAudioSession.interruptionNotification {
                    relevant = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.began.rawValue
                } else { relevant = true }
                guard relevant else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.ownsAudio else { return }
                    self.stop()
                    self.onFailure?()
                }
            }.store(in: &observations)
        }
        NotificationCenter.default.publisher(for: AVAudioSession.silenceSecondaryAudioHintNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.ownsAudio else { return }
                    self.mediaMonitor.check()
                }
            }.store(in: &observations)
    }

    func start() throws {
        stop()
        guard AVAudioApplication.shared.recordPermission == .granted,
              SFSpeechRecognizer.authorizationStatus() == .authorized,
              let recognizer = Self.availableRecognizer() else { throw VoiceInputError.recognizerUnavailable }
        self.recognizer = recognizer
        do {
            try NearMeAudioSession.setWidgetListeningActive(true)
            ownsAudio = true
            let node = engine.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw VoiceInputError.microphoneUnavailable }
            let gate = self.gate
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in gate.append(buffer) }
            tapped = true
            engine.prepare()
            try engine.start()
            mediaMonitor.start()
        } catch { stop(); throw error }
    }

    func resumeRecognition() throws {
        pauseRecognition()
        guard ownsAudio, engine.isRunning, let recognizer, recognizer.isAvailable else {
            throw VoiceInputError.microphoneUnavailable
        }
        let token = self.token
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request
        recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal == true
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.token == token, self.ownsAudio, self.request != nil else { return }
                // The audio-thread gate also rejects buffers while other audio plays.
                guard !self.otherAudio else {
                    self.pauseRecognition(); self.mediaMonitor.check(); return
                }
                if let text, !text.isEmpty, text != self.transcript {
                    let firstWords = self.transcript.isEmpty
                    self.transcript = text
                    if firstWords {
                        self.onSpeech?()
                        self.utteranceLimit = Task { [weak self] in
                            do { try await Task.sleep(for: .seconds(30)) } catch { return }
                            guard let self, self.token == token else { return }
                            self.finish()
                        }
                    }
                    self.endpoint?.cancel()
                    self.endpoint = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(2)) } catch { return }
                        guard let self, self.token == token else { return }
                        self.finish()
                    }
                }
                if final { self.finish() }
                else if failed {
                    self.pauseRecognition()
                    self.onRecognitionEnded?()
                }
            }
        }
        gate.set(request)
    }

    func pauseRecognition() {
        gate.set(nil)
        token = UUID()
        endpoint?.cancel(); endpoint = nil
        utteranceLimit?.cancel(); utteranceLimit = nil
        request?.endAudio(); request = nil
        recognition?.cancel(); recognition = nil
        transcript = ""
    }

    func finish() {
        guard ownsAudio, request != nil else { return }
        let text = transcript
        pauseRecognition()
        onResult?(text)
    }

    func stop() {
        mediaMonitor.stop()
        pauseRecognition()
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        recognizer = nil
        if ownsAudio {
            ownsAudio = false
            try? NearMeAudioSession.setWidgetListeningActive(false)
        }
    }
}
