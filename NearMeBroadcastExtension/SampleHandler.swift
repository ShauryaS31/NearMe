// Adapted from a prior prototype, used with permission.

import Foundation
import CoreFoundation
import ReplayKit
import CoreMedia
import CoreVideo
import CoreImage
import CoreGraphics
import ImageIO
import Vision
import os
import OSLog

nonisolated final class SampleHandler: RPBroadcastSampleHandler {
    private let processor = BroadcastSnapshotProcessor()

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) { startSnapshots() }
    override func broadcastResumed() { startSnapshots() }
    override func broadcastPaused() { processor.stop() }
    override func broadcastFinished() { processor.stop() }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        processor.process(sampleBuffer)
    }

    private func startSnapshots() {
        do { try processor.start() }
        catch {
            processor.stop()
            finishBroadcastWithError(NSError(domain: "au.nearme.ios.broadcast", code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "NearMe could not share screen words. Check App Group signing on the Mac."]))
        }
    }
}

/// No queued frames: processing is synchronous, one frame at a time, at most 1 Hz.
/// Stop deletes AFTER any in-flight write and cannot be undone by that write.
private nonisolated final class BroadcastSnapshotProcessor {
    private let lock = NSLock()
    private let logger = Logger(subsystem: "au.nearme.ios", category: "broadcast")
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let request: VNRecognizeTextRequest
    private var pool: CVPixelBufferPool?
    private var poolWidth = 0
    private var poolHeight = 0
    private var writer: ScreenSnapshotWriter?
    private var lastFrame = -Double.infinity
    private var lastLog = -Double.infinity

    init() {
        request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.recognitionLanguages = ["en"]
        request.usesLanguageCorrection = false
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard let url = SharedScreenBridge.snapshotURL else { throw CocoaError(.fileNoSuchFile) }
        let next = ScreenSnapshotWriter(url: url)
        try next.start()
        writer = next
        lastFrame = -Double.infinity
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        do { try writer?.stop() }
        catch { logger.error("Could not delete screen snapshot") }
        writer = nil
        pool = nil
        context.clearCaches()
    }

    func process(_ sample: CMSampleBuffer) {
        guard lock.try() else { return }
        defer { lock.unlock() }
        let started = ProcessInfo.processInfo.systemUptime
        guard let writer, started - lastFrame >= 1 else { return }
        lastFrame = started
        let timestamp = Date().timeIntervalSince1970
        autoreleasepool {
            do {
                guard let source = CMSampleBufferGetImageBuffer(sample) else { return }
                let attachment = CMGetAttachment(sample, key: RPVideoSampleOrientationKey as CFString,
                                                 attachmentModeOut: nil) as? NSNumber
                let orientation = CGImagePropertyOrientation(rawValue: attachment?.uint32Value ?? 1) ?? .up
                let image = CIImage(cvPixelBuffer: source).oriented(orientation)
                let extent = image.extent
                let scale = min(1, 1_000 / max(extent.width, extent.height))
                let width = max(1, Int(extent.width * scale))
                let height = max(1, Int(extent.height * scale))
                guard let buffer = scaledBuffer(width: width, height: height) else { return }
                let translated = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
                let scaled = translated.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                context.render(scaled, to: buffer)
                let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
                try handler.perform([request])
                let observations: [VNRecognizedTextObservation] = request.results ?? []
                let lines: [ScreenSnapshot.Line] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let box = observation.boundingBox
                    let normalised = ScreenSnapshot.Box(x: max(0, Double(box.minX)),
                        y: max(0, Double(1 - box.maxY)), width: Double(box.width), height: Double(box.height))
                    return ScreenSnapshot.Line(text: candidate.string, box: normalised)
                }
                try writer.write(ScreenSnapshot(timestamp: timestamp, lines: lines))
            } catch {
                // Age the last successful snapshot out. Never log OCR or error payloads.
            }
        }
        let finished = ProcessInfo.processInfo.systemUptime
        if finished - lastLog >= 10 {
            lastLog = finished
            let available = os_proc_available_memory()
            let milliseconds = Int((finished - started) * 1_000)
            logger.notice("available_memory_bytes=\(available, privacy: .public) processing_ms=\(milliseconds, privacy: .public)")
        }
    }

    private func scaledBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        if pool == nil || poolWidth != width || poolHeight != height {
            pool = nil
            context.clearCaches()
            let attributes: [String: Any] = [
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess
            else { return nil }
            poolWidth = width
            poolHeight = height
        }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        let limits = [kCVPixelBufferPoolAllocationThresholdKey as String: 1] as CFDictionary
        guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, limits, &buffer) == kCVReturnSuccess
        else { return nil }
        return buffer
    }
}
