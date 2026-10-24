// Adapted from a prior prototype, used with permission.

import Foundation
import ReplayKit
import CoreMedia
import Dispatch

nonisolated final class SampleHandler: RPBroadcastSampleHandler {
    private let heartbeat = BroadcastHeartbeatWriter()

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        startHeartbeat()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        // Count only. Never extract, retain, encode or write a frame or audio buffer.
        heartbeat.countFrame()
    }

    override func broadcastPaused() { heartbeat.stop() }
    override func broadcastResumed() { startHeartbeat() }
    override func broadcastFinished() { heartbeat.stop() }

    private func startHeartbeat() {
        do {
            try heartbeat.start()
        } catch {
            heartbeat.stop()
            finishBroadcastWithError(NSError(
                domain: "au.nearme.ios.broadcast", code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "NearMe could not share its screen connection status. Check App Group signing on the Mac."]
            ))
        }
    }
}

/// ReplayKit callbacks and the timer share only lock-protected state.
/// The timer publishes even when a static screen produces no new video buffers.
private nonisolated final class BroadcastHeartbeatWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "au.nearme.ios.broadcast.heartbeat")
    private var timer: DispatchSourceTimer?
    private var url: URL?
    private var frameCount = 0

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard timer == nil else { return }
        guard let destination = SharedScreenBridge.heartbeatURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        url = destination
        let value = ScreenBroadcastHeartbeat(timestamp: Date().timeIntervalSince1970, frameCount: frameCount)
        try SharedScreenBridge.write(value, to: destination)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
        source.setEventHandler { [weak self] in self?.publish() }
        timer = source
        source.resume()
    }

    func countFrame() {
        lock.lock()
        defer { lock.unlock() }
        guard timer != nil, frameCount < Int.max else { return }
        frameCount += 1
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        timer?.cancel()
        timer = nil
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
    }

    private func publish() {
        lock.lock()
        defer { lock.unlock() }
        guard timer != nil, let url else { return }
        let value = ScreenBroadcastHeartbeat(timestamp: Date().timeIntervalSince1970, frameCount: frameCount)
        // A write failure ages out in the app; retry on the next tick.
        try? SharedScreenBridge.write(value, to: url)
    }

    deinit { timer?.cancel() }
}
