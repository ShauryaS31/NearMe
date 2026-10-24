// Adapted from a prior prototype, used with permission.

import AVFoundation

nonisolated enum NearMeAudioSession {
    private static let lock = NSLock()
    private static var isConfigured = false

    /// Mix while coaching across apps so the song is not held ducked during waits.
    static func setScreenGuidanceActive(_ active: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        let session = AVAudioSession.sharedInstance()
        if active {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
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
