import Foundation

nonisolated enum VoiceCommand: String, CaseIterable, Sendable {
    case whatsNext = "what's next"
    case next, help, repeatStep = "repeat", stuck = "I'm stuck", stop

    static let phrases = ["what's next", "what next", "what now", "next step", "next",
                          "help", "repeat", "I'm stuck", "stuck", "stop"]
    static var recognitionPhrases: [String] {
        let answers = ["yes", "no"]
        return phrases + answers + (phrases + answers).map { "NearMe " + $0 }
    }

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

    static func prefixedPayload(_ text: String) -> String? {
        guard let prefix = text.range(of: #"^\s*near\s*me[\s,.:;]+"#,
                                      options: [.regularExpression, .caseInsensitive]) else { return nil }
        // Preserve punctuation for the secret filter (for example email addresses).
        return String(text[prefix.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Answers are accepted only while the screen coach has asked a question. No
/// transcription is persisted or sent to a model; rejected content is discarded.
nonisolated enum ScreenVoiceAnswer {
    static func bounded(_ text: String, question: ScreenCoachLoop.Question) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 160, value.split(whereSeparator: \.isWhitespace).count <= 24 else { return nil }
        let normalized = VoiceCommand.normalized(value)
        if question == .playback || question == .reopen {
            if ["yes", "yeah", "yes please", "yes it is", "it is playing", "the song is playing"].contains(normalized) { return "yes" }
            if ["no", "no thanks", "not now", "no it isnt", "it is not playing"].contains(normalized) { return "no" }
            return nil
        }
        let line = ScreenSnapshot.Line(text: value, box: ScreenSnapshot.Box(x: 0, y: 0, width: 1, height: 1))
        guard !ScreenSecretFilter.filtered([line]).isEmpty else { return nil }
        return value
    }
}

nonisolated enum VoiceCommandStatus: Equatable {
    case off, listening, commandWindow, waitingForAudio, paused

    var text: String? {
        switch self {
        case .off: return nil
        case .listening: return "Listening for commands"
        case .commandWindow: return "Say NearMe, then your command or answer"
        case .waitingForAudio: return "Pause other audio, or use Check & listen"
        case .paused: return "Voice commands paused, tap to resume"
        }
    }
}
