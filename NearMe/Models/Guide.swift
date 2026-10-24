import Foundation

nonisolated struct Guide: Codable, Sendable, Equatable, Identifiable {
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

        nonisolated enum CodingKeys: String, CodingKey {
            case instruction, verify
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

    static func validRewrite(_ text: String, guide: Guide, step: Guide.Step) -> Bool {
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
        if step.labelIsNearby == true {
            let label = NSRegularExpression.escapedPattern(for: step.uiLabelHint)
            guard !matches(text, "(?i)\\btap\\s+(?:on\\s+)?(?:the\\s+)?\"\(label)\""),
                  text.localizedCaseInsensitiveContains("Look near \"\(step.uiLabelHint)\"") else { return false }
        }
        return true
    }

    static func validGeneral(_ steps: [String]) -> Bool {
        !steps.isEmpty && steps.count <= 6 && steps.allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 200 &&
            (1...2).contains(sentences($0).count) &&
            !matches($0, #"(?i)\b(always|definitely|certainly|guaranteed|exactly|must|will)\b"#) &&
            !matches($0, #"(?i)(?:\bthen\b|\band\b|;)\s+(tap|open|type|swipe|drag|press|turn|choose)\b"#)
        }
    }

    static func fallback(step: Guide.Step, person: String?, stuck: Bool = false) -> String {
        var text = step.instruction
        if let person = PersonNormalization.normalize(person) {
            if text.hasPrefix("Tap the chat with the person") {
                text = "Open your chat with \(person)."
            } else {
                text = text.replacingOccurrences(of: "the person's", with: "\(person)'s")
                    .replacingOccurrences(of: "the person", with: person)
                    .replacingOccurrences(of: "the matching person", with: person)
            }
        }
        if step.labelIsNearby == true {
            // An orientation sentence plus the original action; keep at most two sentences.
            return "Look near \"\(step.uiLabelHint)\". \(sentences(text).first.map { $0 + "." } ?? text)"
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
        default: return value.capitalized
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
            if !["whatsapp", "facetime", "someone", "person", "me", "wifi", "wi", "phone", "recents", "a contact", "a friend", "my friend"].contains(name.lowercased()) {
                return normalize(name)
            }
        }
        return nil
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
