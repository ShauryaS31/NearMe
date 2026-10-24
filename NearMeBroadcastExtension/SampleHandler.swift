// Adapted from a prior prototype, used with permission.

import ReplayKit
import CoreMedia
import CoreImage

class SampleHandler: RPBroadcastSampleHandler {
    private let ciContext = CIContext()
    /// Throttle: The practice UI doesn't need 30-60fps analysis — a frame every
    /// ~500ms is plenty for "did the user reach a new screen" and keeps
    /// battery/CPU use in the extension's tight memory budget reasonable.
    private var lastWriteTime: CFAbsoluteTime = 0
    private let minimumWriteInterval: CFTimeInterval = 0.5

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // Nothing to set up — SharedScreenBridge resolves its container URL lazily.
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastWriteTime >= minimumWriteInterval else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let url = SharedScreenBridge.latestFrameURL else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let colorSpace = ciImage.colorSpace,
              let jpegData = ciContext.jpegRepresentation(of: ciImage, colorSpace: colorSpace) else { return }

        do {
            try jpegData.write(to: url, options: .atomic)
            SharedScreenBridge.notifyNewFrameAvailable()
            lastWriteTime = now
        } catch {
            // Best-effort — dropping an occasional frame is fine.
        }
    }

    override func broadcastFinished() {
        // Nothing to tear down.
    }
}
