import Foundation

nonisolated enum VoiceCommand: String, CaseIterable, Sendable {
    case whatsNext = "what's next"
    case next, help, repeatStep = "repeat", stuck = "I'm stuck", stop

    static let phrases = ["what's next", "what next", "what now", "next step", "next",
                          "help", "repeat", "I'm stuck", "stuck", "stop"]

    static func normalized(_ text: String) -> String {
        let apostrophes = text.replacingOccurrences(of: "’", with: "").replacingOccurrences(of: "'", with: "")
        let words = apostrophes.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        return words.filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func match(_ text: String) -> VoiceCommand? {
        let value = normalized(text)
        // Longest phrases first, with a word boundary ("context" is not "next").
        let variants: [(String, VoiceCommand)] = [
            ("whats next", .whatsNext), ("what next", .whatsNext), ("what now", .whatsNext),
            ("next step", .whatsNext), ("im stuck", .stuck), ("stuck", .stuck),
            ("next", .next), ("help", .help), ("repeat", .repeatStep), ("stop", .stop)
        ]
        for (phrase, command) in variants {
            if value == phrase || value.hasSuffix(" " + phrase) { return command }
        }
        return nil
    }
}

nonisolated enum VoiceCommandStatus: Equatable {
    case off, listening, paused

    var text: String? {
        switch self {
        case .off: return nil
        case .listening: return "Listening for commands"
        case .paused: return "Voice commands paused, tap to resume"
        }
    }
}
