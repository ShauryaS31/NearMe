import AVFoundation
import Foundation

@MainActor
protocol ScreenGuidanceKeepingAlive {
    func start()
    func stop()
}

/// Scoped to a fresh YouTube sharing session. The existing silent PCM resource
/// keeps the audio render path running between spoken instructions. Real-device
/// suspension, interruptions and coexistence with YouTube remain a device gate.
@MainActor
final class ScreenGuidanceAudioLease: ScreenGuidanceKeepingAlive {
    private var player: AVAudioPlayer?
    private var configured = false

    func start() {
        guard player?.isPlaying != true else { return }
        do {
            try NearMeAudioSession.setScreenGuidanceActive(true)
            configured = true
            guard let url = Bundle.main.url(forResource: "coach-step-silent", withExtension: "wav") else { stop(); return }
            let next = try AVAudioPlayer(contentsOf: url)
            next.numberOfLoops = -1
            next.volume = 0
            guard next.play() else { stop(); return }
            player = next
        } catch {
            // Capture freshness remains authoritative even if background audio fails.
            stop()
        }
    }

    func stop() {
        guard configured else { return }
        player?.stop()
        player = nil
        configured = false
        try? NearMeAudioSession.setScreenGuidanceActive(false)
    }
}
