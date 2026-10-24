import AVFoundation
import Foundation

@MainActor
protocol VoiceAudioPlaying: AnyObject {
    var rate: Float { get set }
    func prepare(_ data: Data) throws
    func play() async -> Bool
    func stop()
}

@MainActor
final class VoiceAudioPlayer: NSObject, VoiceAudioPlaying, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var completion: CheckedContinuation<Bool, Never>?
    private var watchdog: Task<Void, Never>?
    var rate: Float = 1

    func prepare(_ data: Data) throws {
        stop()
        try NearMeAudioSession.configureIfNeeded()
        let player = try AVAudioPlayer(data: data)
        player.enableRate = true
        player.rate = rate
        guard player.prepareToPlay(), player.duration > 0 else { throw VoicePlaybackError.decode }
        player.delegate = self
        self.player = player
    }

    func play() async -> Bool {
        guard let player else { return false }
        return await withCheckedContinuation { continuation in
            completion = continuation
            guard player.play() else { finish(false); return }
            watchdog = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(player.duration / Double(player.rate) + 1)) }
                catch { return }
                guard let self, self.player === player else { return }
                self.finish(false)
            }
        }
    }

    func stop() { finish(false) }

    private func finish(_ success: Bool) {
        watchdog?.cancel()
        watchdog = nil
        player?.stop()
        player = nil
        let pending = completion
        completion = nil
        pending?.resume(returning: success)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player else { return }
            finish(flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard self.player === player else { return }
            finish(false)
        }
    }
}

enum VoicePlaybackError: Error {
    case decode
    case http(Int)
    case request
}
