import Foundation

nonisolated struct HelpGuide: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let app: String
    let appURLScheme: String?
    let aliases: [String]
    let steps: [Step]
    let sourceNote: String
    let lastChecked: String

    nonisolated enum CodingKeys: String, CodingKey {
        case id, title, app, aliases, steps
        case appURLScheme = "app_url_scheme", sourceNote = "source_note", lastChecked = "last_checked"
    }

    nonisolated struct Step: Codable, Sendable, Equatable {
        let instruction: String
        let uiLabelHint: String
        var verify: Bool? = nil
        var labelIsNearby: Bool? = nil
        var icon: String? = nil

        nonisolated enum CodingKeys: String, CodingKey {
            case instruction, verify, icon
            case uiLabelHint = "ui_label_hint", labelIsNearby = "label_is_nearby"
        }
    }
}

nonisolated enum CoachText {
    static let generalFallback = "I'm not sure about that one. Try asking a family member, or ask me another way."

    static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    static func sentences(_ text: String) -> [String] {
        text.replacingOccurrences(of: #"[.!?]+(?:\s+|$)"#, with: "\n", options: .regularExpression)
            .components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    static func validRewrite(_ text: String, guide: HelpGuide, step: HelpGuide.Step) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= 200, (1...2).contains(sentences(text).count),
              !text.contains(where: { $0.isNewline }),
              !text.contains(where: { "“”„«»".contains($0) }) else { return false }
        let parts = text.components(separatedBy: "\"")
        guard parts.count % 2 == 1 else { return false }
        let hints = Set(guide.steps.map(\.uiLabelHint))
        for index in stride(from: 1, to: parts.count, by: 2) {
            guard hints.contains(parts[index]) else { return false }
        }
        // The current label must survive a rewrite; quoted labels cannot be invented.
        guard text.contains("\"\(step.uiLabelHint)\"") else { return false }
        if step.instruction.contains("the person or number"), !text.contains("the person or number") { return false }
        if step.labelIsNearby == true {
            let label = NSRegularExpression.escapedPattern(for: step.uiLabelHint)
            guard !matches(text, "(?i)\\btap\\s+(?:on\\s+)?(?:the\\s+)?\"\(label)\""),
                  !matches(text, #"(?i)\blook\s+near\b"#) else { return false }
        }
        return true
    }

    static func validGeneral(_ steps: [String]) -> Bool {
        generalRejection(steps) == nil
    }

    /// Fixed rule names only: never log generated text. These are the existing validator rules.
    static func generalRejection(_ steps: [String]) -> String? {
        guard !steps.isEmpty && steps.count <= 6 else { return "step count" }
        for text in steps {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "empty step" }
            guard text.count <= 200 else { return "step length" }
            guard (1...2).contains(sentences(text).count) else { return "sentence count" }
            if matches(text, #"(?i)\b(always|definitely|certainly|guaranteed|exactly|must|will)\b"#) { return "certainty word" }
            if matches(text, #"(?i)(?:\bthen\b|\band\b|;)\s+(tap|open|type|swipe|drag|press|turn|choose)\b"#) { return "multiple actions" }
        }
        return nil
    }

    static func fallback(step: HelpGuide.Step, person: String?, stuck: Bool = false) -> String {
        var text = step.instruction
        if step.labelIsNearby == true, step.uiLabelHint == "Chats" {
            let target = PersonNormalization.normalize(person) ?? "the person"
            return "In your \"Chats\" list, tap \(target)'s name."
        }
        if let person = PersonNormalization.normalize(person) {
            text = text.replacingOccurrences(of: "the person's", with: "\(person)'s")
                .replacingOccurrences(of: #"the person(?! or number)\b"#, with: person, options: .regularExpression)
                .replacingOccurrences(of: "the matching person", with: person)
        }
        if step.labelIsNearby == true {
            if text.contains("\"\(step.uiLabelHint)\"") { return text }
            // Locate the actual target beside a landmark, preserving the action and any second sentence.
            return "By \"\(step.uiLabelHint)\", \(text.prefix(1).lowercased())\(text.dropFirst())"
        }
        return stuck ? "\(text) Look for \"\(step.uiLabelHint)\"." : text
    }
}

nonisolated enum PersonNormalization {
    static func normalize(_ value: String?) -> String? {
        guard let value = PlaceNormalization.normalize(value) else { return nil }
        switch value.lowercased().replacingOccurrences(of: #"^(my|your)\s+"#, with: "", options: .regularExpression) {
        case "mom", "mum", "mummy", "mother": return "Mum"
        case "dad", "daddy", "father": return "Dad"
        case "son": return "your son"
        case "daughter": return "your daughter"
        default:
            guard !CoachText.matches(value, #"(?i)^the\s+"#) else { return nil }
            return value.capitalized
        }
    }

    static func extract(from request: String) -> String? {
        if let range = request.range(of: #"(?i)\b(?:(?:my|your)\s+)?(mom|mum|mummy|mother|dad|daddy|father|son|daughter)\b"#,
                                     options: .regularExpression) {
            return normalize(String(request[range]))
        }
        // Names after an explicit recipient marker. Do not mistake app names for people.
        if CoachText.matches(request, #"(?i)\b(send|share|photo|image|pictures|message|call|chat)\b"#),
           let regex = try? NSRegularExpression(pattern: #"(?i)\b(?:to|with|call)\s+([a-z]+(?:\s+[a-z]+){0,2}?)(?:\s+(?:on|using|via)\b|[.!?]*$)"#),
           let match = regex.firstMatch(in: request, range: NSRange(request.startIndex..., in: request)),
           let range = Range(match.range(at: 1), in: request) {
            let name = String(request[range])
            return extractedPerson(name)
        }
        return nil
    }

    /// Validate a model-supplied recipient with the same rules as keyword extraction.
    static func extractedPerson(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if CoachText.matches(value, #"(?i)^(?:(?:my|your)\s+)?(?:mom|mum|mummy|mother|dad|daddy|father|son|daughter)$"#) {
            return normalize(value)
        }
        let words = value.split(separator: " ")
        guard words.allSatisfy({ $0.first?.isUppercase == true }),
              !["whatsapp", "facetime", "someone", "person", "me", "wifi", "wi", "phone", "recents", "a contact", "a friend", "my friend"].contains(value.lowercased()) else { return nil }
        return normalize(value)
    }
}

nonisolated enum CoachCommand: String, CaseIterable, Sendable {
    case next, repeatStep, slower, stuck, stop
    static func parse(_ text: String) -> CoachCommand? {
        switch text.lowercased().replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) {
        case "done", "next", "ok", "okay", "got it": return .next
        case "repeat": return .repeatStep
        case "slower": return .slower
        case "i'm stuck", "im stuck", "i am stuck", "stuck": return .stuck
        case "stop", "end": return .stop
        default: return nil
        }
    }
}
