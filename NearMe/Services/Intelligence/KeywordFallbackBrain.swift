// Adapted from a prior prototype, used with permission.

import Foundation

struct KeywordFallbackBrain: TaskPlannerBrain {
    private let transportModes = ["train", "tram", "bus", "vline", "v/line"]

    func extractIntent(from utterance: String) async throws -> JourneyIntent {
        let lowered = " \(utterance.lowercased()) " // pad so " to "/" from " matches at the edges too

        guard lowered.contains("catch") || lowered.contains("train") || lowered.contains("tram")
                || lowered.contains("bus") || lowered.contains(" to ") || lowered.contains("get to")
                || lowered.contains("travel") || lowered.contains("go to") else {
            return JourneyIntent(intent: .unknown, destination: nil, origin: nil, mode: nil)
        }

        let mode = transportModes.first { lowered.contains($0) }
        let destination = lastPhrase(after: " to ", in: utterance, stoppingAt: [" from "])
        let origin = firstPhrase(after: " from ", in: utterance, stoppingAt: [" to "])

        guard destination != nil || origin != nil else {
            return JourneyIntent(intent: .unknown, destination: nil, origin: nil, mode: mode)
        }

        return JourneyIntent(intent: .planJourney, destination: destination, origin: origin, mode: mode)
    }

    func clarifyingQuestion(for missing: MissingSlot, currentIntent: JourneyIntent) async throws -> String {
        switch missing {
        case .origin:
            return "Sure! Where are you leaving from?"
        case .destination:
            return "Got it — and where are you headed?"
        }
    }

    func confirmationLine(for intent: JourneyIntent) async throws -> String {
        "Great! I'll help you plan that journey."
    }

    /// Finds the LAST occurrence of `marker` (e.g. " to ") and returns
    /// whatever follows it, trimmed at the first of `stopMarkers` or the end
    /// of the sentence. Using the *last* occurrence matters because a
    /// sentence like "I need to catch the train to Melbourne Central" has
    /// an earlier, irrelevant "to" (in "need to catch") before the one that
    /// actually introduces the destination.
    private func lastPhrase(after marker: String, in text: String, stoppingAt stopMarkers: [String]) -> String? {
        let padded = " \(text) "
        guard let markerRange = padded.range(of: marker, options: [.backwards, .caseInsensitive]) else { return nil }
        return extractPhrase(from: padded, startingAfter: markerRange.upperBound, stoppingAt: stopMarkers)
    }

    /// Same as `lastPhrase`, but anchored to the first occurrence of
    /// `marker` — used for origin ("from"), which typically appears once.
    private func firstPhrase(after marker: String, in text: String, stoppingAt stopMarkers: [String]) -> String? {
        let padded = " \(text) "
        guard let markerRange = padded.range(of: marker, options: [.caseInsensitive]) else { return nil }
        return extractPhrase(from: padded, startingAfter: markerRange.upperBound, stoppingAt: stopMarkers)
    }

    private func extractPhrase(from text: String, startingAfter index: String.Index, stoppingAt stopMarkers: [String]) -> String? {
        var slice = text[index...]

        for stopMarker in stopMarkers {
            if let stopRange = slice.range(of: stopMarker, options: .caseInsensitive) {
                slice = slice[slice.startIndex..<stopRange.lowerBound]
            }
        }

        let trimmed = slice.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!?")))
        return trimmed.isEmpty ? nil : trimmed
    }
}
