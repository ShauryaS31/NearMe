// Adapted from a prior prototype, used with permission.

import Foundation
import Vision
import CoreImage

@MainActor
final class ReplayKitVisionGuidanceService: ScreenGuidanceService {
    var onElementDetected: ((DetectedScreenElement) -> Void)?

    private var watchedLabels: [String] = []
    private var frameToken: DarwinNotificationToken?
    private let ciContext = CIContext()

    func startWatching() {
        frameToken = SharedScreenBridge.observeNewFrames { [weak self] in
            Task { @MainActor in self?.handleNewFrame() }
        }
    }

    func stopWatching() {
        frameToken = nil
    }

    func lookFor(labels: [String]) {
        watchedLabels = labels
    }

    private func handleNewFrame() {
        guard !watchedLabels.isEmpty,
              let url = SharedScreenBridge.latestFrameURL,
              let data = try? Data(contentsOf: url),
              let ciImage = CIImage(data: data) else { return }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self, error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }

            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                for label in self.watchedLabels where candidate.string.localizedCaseInsensitiveContains(label) {
                    let element = DetectedScreenElement(text: candidate.string, boundingBox: observation.boundingBox)
                    Task { @MainActor in self.onElementDetected?(element) }
                    return
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? handler.perform([request])
    }
}
