// Adapted from a prior prototype, used with permission.

import Foundation

struct KeywordFallbackBrain: TaskPlannerBrain {
    let initialSource: BrainSource = .keywordFallback
    private let transportModes = ["train", "tram", "bus"]

    func extractIntent(from utterance: String) async throws -> BrainAnswer<JourneyIntent> {
        let lowered = " \(utterance.lowercased()) " // pad so " to "/" from " matches at the edges too

        guard lowered.contains("catch") || lowered.contains("train") || lowered.contains("tram")
                || lowered.contains("bus") || lowered.contains(" to ") || lowered.contains("get to")
                || lowered.contains("travel") || lowered.contains("go to") else {
            return BrainAnswer(value: .empty, source: .keywordFallback)
        }

        let mode = transportModes.first { lowered.contains($0) }
        let destination = lastPhrase(after: " to ", in: utterance, stoppingAt: [" from "])
        let origin = firstPhrase(after: " from ", in: utterance, stoppingAt: [" to "])

        guard destination != nil || origin != nil else {
            return BrainAnswer(value: JourneyIntent(intent: .unknown, destination: nil, origin: nil, mode: mode), source: .keywordFallback)
        }

        return BrainAnswer(value: JourneyIntent(intent: .planJourney, destination: destination, origin: origin, mode: mode), source: .keywordFallback)
    }

    func extractPlace(from answer: String, for slot: MissingSlot) async throws -> BrainAnswer<String?> {
        var place = trimEdges(answer)
        let prefixes = ["I'm leaving from", "I’m leaving from", "I am leaving from",
                        "I'm at", "I’m at", "I am at", "from", "to", "it's", "it’s", "it is", "um", "uh", "er"]
        while let prefix = prefixes.first(where: {
            place.lowercased() == $0.lowercased() || place.lowercased().hasPrefix($0.lowercased() + " ")
                || place.lowercased().hasPrefix($0.lowercased() + ",")
        }) {
            place = trimEdges(String(place.dropFirst(prefix.count)))
        }
        return BrainAnswer(value: stripTrailingFiller(place), source: .keywordFallback)
    }

    /// Finds the LAST occurrence of `marker` (e.g. " to ") and returns
    /// whatever follows it, trimmed at the first of `stopMarkers` or the end
    /// of the sentence. Using the *last* occurrence matters because a
    /// sentence like "I need to catch the train to Town Hall" has
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

        return stripTrailingFiller(String(slice))
    }

    private func trimEdges(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func stripTrailingFiller(_ text: String) -> String? {
        var place = trimEdges(text)
        let fillers = ["please", "thanks", "thank you", "um", "uh", "er"]
        while let filler = fillers.first(where: {
            place.lowercased() == $0 || place.lowercased().hasSuffix(" " + $0)
                || place.lowercased().hasSuffix("," + $0)
        }) {
            place = trimEdges(String(place.dropLast(filler.count)))
        }
        return place.isEmpty ? nil : place
    }
}
