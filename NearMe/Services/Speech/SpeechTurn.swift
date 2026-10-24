import Foundation
import OSLog
import Speech

nonisolated enum PracticeVocabulary {
    static let places = ["Central", "Town Hall", "Parramatta", "Holsworthy", "Circular Quay",
                         "Bondi Junction", "Strathfield", "Chatswood"]
    static let phrases = places + ["help", "practice", "type instead"]
    static let confidenceThreshold = 0.5
    static let editDistanceThreshold = 3

    static func containsPlace(_ text: String) -> Bool {
        let words = " " + normalized(text) + " "
        return places.contains { words.contains(" " + normalized($0) + " ") }
    }

    /// Compare word windows so sentence filler does not dominate the place score.
    static func closestPlaces(to text: String) -> [String] {
        guard let place = PlaceNormalization.normalize(text) else { return [] }
        let words = normalized(place).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
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
        return places.map { (place: $0, score: score($0)) }
            .filter { $0.score <= editDistanceThreshold * 4 }
            .sorted { $0.score == $1.score ? $0.place < $1.place : $0.score < $1.score }
            .prefix(2).map { $0.place }
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

    /// A decoder deadline must preserve words already recognized, including partials.
    static func transcriptResult(_ latestTranscript: String) -> Result<String, Error> {
        let text = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .failure(VoiceInputError.noSpeechDetected) : .success(text)
    }
}

nonisolated enum SpeechEndReason: String {
    case tap
    case wordsSettled = "words settled"
    case cap = "12 s cap"
}

/// Recognizer activity only: microphone loudness is deliberately not an input.
nonisolated struct SpeechSilenceRule {
    static let interval: TimeInterval = 1.5
    static let hardCap: TimeInterval = 12
    static let finalResultWait: TimeInterval = 1
    static let playbackSettle: TimeInterval = 0.15
    private let now: @Sendable () -> TimeInterval
    private let startedAt: TimeInterval
    private var transcript = ""
    private(set) var lastActivity: TimeInterval?

    init(now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
        self.startedAt = now()
    }

    mutating func observe(transcript: String) {
        guard transcript != self.transcript else { return }
        self.transcript = transcript
        lastActivity = now()
    }

    var hasEnded: Bool {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let lastActivity else { return false }
        return now() - lastActivity >= Self.interval
    }

    var duration: TimeInterval { max(0, now() - startedAt) }

    var endReason: SpeechEndReason? {
        if duration >= Self.hardCap { return .cap }
        return hasEnded ? .wordsSettled : nil
    }

    func logEnd(reason: SpeechEndReason, transcript: String, voiceProcessing: Bool, duration: TimeInterval) {
        let outcome = transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "no words" : reason.rawValue
        VoiceDiagnostics.logger.info("Input voice processing=\(voiceProcessing ? "on" : "off", privacy: .public) end=\(outcome, privacy: .public) trigger=\(reason.rawValue, privacy: .public) duration=\(duration) s")
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
