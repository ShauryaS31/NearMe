import AVFoundation
import Foundation
import Speech

nonisolated enum PracticeVocabulary {
    static let places = ["Central", "Town Hall", "Parramatta", "Holsworthy", "Circular Quay",
                         "Bondi Junction", "Strathfield", "Chatswood"]
    static let phrases = places + ["help", "practice", "type instead"]
    static let confidenceThreshold = 0.5

    static func containsPlace(_ text: String) -> Bool {
        let words = " " + normalized(text) + " "
        return places.contains { words.contains(" " + normalized($0) + " ") }
    }

    /// Compare word windows so sentence filler does not dominate the place score.
    static func closestPlaces(to text: String) -> [String] {
        let words = normalized(text).split(separator: " ").map(String.init)
        func score(_ place: String) -> Int {
            let target = normalized(place)
            let count = target.split(separator: " ").count
            var scores: [Int] = []
            for start in words.indices {
                for length in max(1, count - 1)...(count + 1) where start + length <= words.count {
                    let candidate = words[start..<(start + length)].joined(separator: " ")
                    let prefix = target.hasPrefix(candidate) || candidate.hasPrefix(target)
                    scores.append(distance(candidate, target) * 4 - (prefix ? 1 : 0))
                }
            }
            return scores.min() ?? target.count * 4
        }
        return Array(places.sorted {
            let a = score($0), b = score($1)
            return a == b ? $0 < $1 : a < b
        }.prefix(2))
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }

    private static func distance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        var previous = Array(0...b.count)
        for (i, character) in a.enumerated() {
            var row = [i + 1]
            for (j, other) in b.enumerated() {
                row.append(min(row[j] + 1, previous[j + 1] + 1, previous[j] + (character == other ? 0 : 1)))
            }
            previous = row
        }
        return previous[b.count]
    }

    @available(iOS 26.0, *)
    static func analysisContext() -> AnalysisContext {
        let context = AnalysisContext()
        context.contextualStrings[.general] = phrases
        return context
    }
}

nonisolated struct SpeechTurn {
    var endedAt: TimeInterval?
    var confidence: Double?
}

/// Shared acoustic silence policy. Tests inject a monotonic clock without sleeping.
nonisolated struct SpeechSilenceRule {
    static let interval: TimeInterval = 0.8
    private let now: @Sendable () -> TimeInterval
    private(set) var lastActivity: TimeInterval?

    init(now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
    }

    mutating func observe(isSpeech: Bool) {
        if isSpeech { lastActivity = now() }
    }

    var hasEnded: Bool {
        guard let lastActivity else { return false }
        return now() - lastActivity >= Self.interval
    }

    /// A small RMS gate avoids treating decoder callback latency as speech activity.
    static func hasSpeech(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return false }
        let samples = channels[0]
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
        return sum / Float(buffer.frameLength) > 0.0001
    }
}

enum PlannerTemplates {
    static func question(for slot: MissingSlot) -> String {
        slot == .origin ? "Where are you starting from?" : "Where would you like to go?"
    }

    static func confirmation(for intent: JourneyIntent) -> String {
        guard let origin = intent.origin, let destination = intent.destination else {
            return "Let's practise planning a trip."
        }
        return "Great, let's practise planning a trip from \(origin) to \(destination)."
    }
}
