// Adapted from a prior prototype, used with permission.

import AVFoundation

nonisolated enum NearMeAudioSession {
    private static let lock = NSLock()
    private static var isConfigured = false
    private static var screenActive = false
    private static var commandsActive = false
    private static var widgetActive = false
    private static var guidanceSpeaking = false

    static func guidanceOptions(speaking: Bool) -> AVAudioSession.CategoryOptions {
        var options: AVAudioSession.CategoryOptions = [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP]
        if speaking { options.insert(.duckOthers) }
        return options
    }

    static func setCommandListeningActive(_ active: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        commandsActive = active
        try applyGuidanceSession()
    }

    static func setWidgetListeningActive(_ active: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        widgetActive = active
        do { try applyGuidanceSession() }
        catch { widgetActive = false; throw error }
    }

    static func setGuidanceSpeaking(_ speaking: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        guidanceSpeaking = speaking
        guard screenActive || commandsActive || widgetActive else { return }
        try applyGuidanceSession()
    }

    /// Mix while coaching across apps so the song is not held ducked during waits.
    static func setScreenGuidanceActive(_ active: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        screenActive = active
        try applyGuidanceSession()
    }

    private static func applyGuidanceSession() throws {
        let session = AVAudioSession.sharedInstance()
        if screenActive || commandsActive || widgetActive {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: guidanceOptions(speaking: guidanceSpeaking))
            try session.setActive(true)
            isConfigured = true
        } else {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            isConfigured = false
        }
    }

    /// Configures the app's one persistent audio session for the whole
    /// voice conversation. Safe to call repeatedly, and safe to call from
    /// any thread — only does real work once per app launch (and will
    /// retry if an earlier attempt failed).
    static func configureIfNeeded() throws {
        lock.lock()
        let alreadyConfigured = isConfigured
        lock.unlock()
        guard !alreadyConfigured else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            lock.lock()
            isConfigured = true
            lock.unlock()
        } catch {
            VoiceDiagnostics.log(error)
            // Leave isConfigured false so the next attempt (the next time
            // speak() or startListening() is called) tries again rather
            // than silently giving up for the rest of the app's lifetime.
            throw VoiceInputError.audioEngineFailed(error)
        }
    }
}
