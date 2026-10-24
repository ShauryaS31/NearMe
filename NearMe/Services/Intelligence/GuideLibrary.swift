import Foundation

nonisolated enum GuideLibraryError: Error { case invalid(String) }

nonisolated enum GuideLibrary {
    static let expectedApps = [
        "whatsapp_send_photo": "WhatsApp", "whatsapp_video_call": "WhatsApp",
        "whatsapp_voice_message": "WhatsApp", "iphone_text_bigger": "Settings",
        "connect_wifi": "Settings", "take_screenshot": "iPhone", "share_photo_from_photos": "Photos",
        "facetime_contact": "FaceTime", "add_contact": "Contacts", "turn_on_do_not_disturb": "Control Centre",
        "check_ios_update": "Settings", "set_alarm": "Clock", "call_from_recents": "Phone",
        "turn_on_torch": "Control Centre", "send_text_message": "Messages"
    ]

    static func load(bundle: Bundle? = nil) throws -> [HelpGuide] {
        let bundle = bundle ?? .main
        guard let directory = bundle.url(forResource: "guides", withExtension: nil) else {
            throw GuideLibraryError.invalid("Missing bundled guides directory")
        }
        return try load(directory: directory)
    }

    static func load(directory: URL) throws -> [HelpGuide] {
        let entries = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let files: [URL] = entries.filter { $0.pathExtension == "json" }
        guard Set(files.map(\.lastPathComponent)) == Set(expectedApps.keys.map { $0 + ".json" }) else {
            throw GuideLibraryError.invalid("Expected exactly the 15 guide files")
        }
        let guides = try files.sorted { $0.lastPathComponent < $1.lastPathComponent }.map {
            try decode(Data(contentsOf: $0), filename: $0.deletingPathExtension().lastPathComponent)
        }
        guard Set(guides.map(\.id)).count == 15 else { throw GuideLibraryError.invalid("Duplicate ids") }
        return guides
    }

    static func validReviewDate(_ value: String) -> Bool {
        guard CoachText.matches(value, #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#) else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }

    static func bundled() -> [HelpGuide] { bundledGuides }

    private static let bundledGuides: [HelpGuide] = {
        do { return try load() }
        catch {
            #if DEBUG
            assertionFailure("Guide library validation failed: \(error)")
            #endif
            return []
        }
    }()

    /// Mirrors scripts/validate-guides.py, including editorial heuristics and file format.
    static func decode(_ data: Data, filename: String) throws -> HelpGuide {
        guard let text = String(data: data, encoding: .utf8) else { throw GuideLibraryError.invalid("UTF-8") }
        var canonical = GuideJSONFormat(text: text)
        try canonical.validate()
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GuideLibraryError.invalid("Expected object")
        }
        func require(_ condition: Bool, _ reason: String) throws {
            if !condition { throw GuideLibraryError.invalid("\(filename): \(reason)") }
        }
        func fields(_ object: [String: Any], required: Set<String>, optional: Set<String>) throws {
            let keys = Set(object.keys)
            try require(required.isSubset(of: keys) && keys.isSubset(of: required.union(optional)), "Invalid fields")
        }
        try fields(root, required: ["id", "title", "app", "aliases", "steps", "source_note", "last_checked"], optional: ["app_url_scheme"])
        let guide = try JSONDecoder().decode(HelpGuide.self, from: data)
        try require(guide.id == filename && expectedApps[guide.id] == guide.app, "Id/app/filename mismatch")
        try require(validReviewDate(guide.lastChecked), "Review date")
        if root.keys.contains("app_url_scheme") {
            let allowed = guide.id.hasPrefix("whatsapp_") ? "whatsapp://" : (guide.id == "send_text_message" ? "sms:" : nil)
            try require(allowed != nil && guide.appURLScheme == allowed, "Unsupported scheme")
        }
        let mixed = #"\b(?:bhejna|bhejni|bheje|bada|badi|karna|karni|karo|kaise|kare|hai|hain|ki|ka|pe|par|se|lagana|lagao|chalu|jalao|leni|lena|lete|awaaz|tasveer|naya|banana|subah|aaya|kya|wapas|jisne|jodna)\b"#
        let aliases = guide.aliases.map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        let english = aliases.filter { !CoachText.matches($0, mixed) }
        try require((6...10).contains(aliases.count) && Set(aliases).count == aliases.count &&
                    aliases.allSatisfy { $0 == $0.lowercased() } &&
                    aliases.filter { CoachText.matches($0, mixed) }.count >= 2 &&
                    english.contains { $0.split(separator: " ").count <= 5 }, "Aliases")
        try require((3...8).contains(guide.steps.count), "Step count")
        let hints = Set(guide.steps.map(\.uiLabelHint))
        guard let rawSteps = root["steps"] as? [[String: Any]] else { throw GuideLibraryError.invalid("Steps") }
        let capitalWords = Set("WhatsApp FaceTime Settings Display Brightness Text Size Wi Fi Join Save Photos Library Messages To New Call Contacts First Last Phone Do Not Disturb Focus General Software Update Clock Alarms AM PM Calls Chats".split(separator: " ").map(String.init))
        for (step, raw) in zip(guide.steps, rawSteps) {
            try fields(raw, required: ["instruction", "ui_label_hint"], optional: ["verify", "label_is_nearby"])
            // JSONDecoder rejects non-boolean values, including numbers and null for present flags.
            for flag in ["verify", "label_is_nearby"] where raw.keys.contains(flag) {
                try require((flag == "verify" ? step.verify : step.labelIsNearby) != nil, "Null boolean")
            }
            let instruction = step.instruction
            let parts = instruction.components(separatedBy: "\"")
            try require(!step.uiLabelHint.contains("\"") && parts.count % 2 == 1, "Quote delimiters")
            for i in stride(from: 1, to: parts.count, by: 2) { try require(hints.contains(parts[i]), "Unknown quoted label") }
            let sentences = CoachText.sentences(instruction)
            try require(instruction.unicodeScalars.count <= 200 && sentences.count <= 2 &&
                        sentences.allSatisfy { $0.split(whereSeparator: \.isWhitespace).count <= 25 }, "Instruction length")
            try require(!CoachText.matches(instruction, #"(?i)\b(select|click|cta|hamburger|modal|dropdown|long-press|NearMe)\b"#), "Jargon")
            let password = "Type the Wi-Fi password, then tap \"Join\"."
            try require(!CoachText.matches(instruction, #"(?i)(?:\bthen\b|\band\b|;)\s+(tap|open|type|swipe|drag|press|turn|touch|say|set|check|choose|enter|send)\b"#) || instruction == password, "Multiple actions")
            try require(!CoachText.matches(instruction, #"(?i)\b(password|passcode|pin|verification code|security code|otp)\b"#) ||
                        (guide.id == "connect_wifi" && instruction == password), "Credential instruction")
            for sentence in sentences {
                let regex = try NSRegularExpression(pattern: #"\b[A-Z][A-Za-z]*\b"#)
                var words = regex.matches(in: sentence, range: NSRange(sentence.startIndex..., in: sentence))
                    .compactMap { Range($0.range, in: sentence).map { String(sentence[$0]) } }
                if CoachText.matches(sentence, #"^[A-Z][A-Za-z]*\b"#), !words.isEmpty { words.removeFirst() }
                try require(Set(words).isSubset(of: capitalWords), "Unexpected capitalised word")
            }
        }
        try require(CoachText.matches(guide.sourceNote, #"\biOS 26(?:/27)?\b|\biOS 27\b"#) && guide.sourceNote.contains(guide.app), "Source layout/app")
        func validateStrings(_ value: Any) throws {
            if let string = value as? String {
                try require(!string.isEmpty && string == string.trimmingCharacters(in: .whitespacesAndNewlines), "Empty/padded text")
                try require(!string.unicodeScalars.contains { $0.value < 32 } && !string.contains(where: { "—“”„«»".contains($0) }), "Text punctuation/control characters")
                try require(!CoachText.matches(string, #"(?i)(?:app-prefs|prefs):|[$£€₹]|\b\d+(?:\.\d+)?\s*(?:usd|aud|gbp|inr)\b|\b(inches|inch|feet|foot|miles|mile|pounds|lbs|fahrenheit)\b"#), "Private URL/price/units")
            } else if let object = value as? [String: Any] {
                for child in object.values { try validateStrings(child) }
            } else if let array = value as? [Any] {
                for child in array { try validateStrings(child) }
            }
        }
        try validateStrings(root)
        return guide
    }
}

/// A format-only JSON reader preserves key order (JSONSerialization does not).
/// Its canonical rendering also rejects duplicate keys and escaped Unicode.
nonisolated private struct GuideJSONFormat {
    let text: String
    private var characters: [Character] = []
    private var index = 0
    init(text: String) { self.text = text }

    mutating func validate() throws {
        characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        let rendered = try value(depth: 0) + "\n"
        whitespace()
        guard index == characters.count, String(characters) == rendered else { throw GuideLibraryError.invalid("Use canonical two-space JSON and final newline") }
    }
    private mutating func whitespace() {
        while index < characters.count && characters[index].isWhitespace { index += 1 }
    }
    private mutating func take(_ char: Character) -> Bool {
        whitespace()
        guard index < characters.count, characters[index] == char else { return false }
        index += 1
        return true
    }
    private mutating func string() throws -> String {
        whitespace()
        let start = index
        guard take("\"") else { throw GuideLibraryError.invalid("JSON string") }
        var escaped = false
        while index < characters.count {
            let char = characters[index]
            index += 1
            if escaped {
                guard char == "\"" || char == "\\" else { throw GuideLibraryError.invalid("Use literal Unicode, no controls") }
                escaped = false
            } else if char == "\\" { escaped = true }
            else if char == "\"" { return String(characters[start..<index]) }
        }
        throw GuideLibraryError.invalid("Unterminated string")
    }
    private mutating func value(depth: Int) throws -> String {
        whitespace()
        guard depth < 16, index < characters.count else { throw GuideLibraryError.invalid("JSON depth/end") }
        if characters[index] == "\"" { return try string() }
        let object = characters[index] == "{"
        if object || characters[index] == "[" {
            index += 1
            let end: Character = object ? "}" : "]"
            if take(end) { return object ? "{}" : "[]" }
            var children: [String] = []
            var keys = Set<String>()
            repeat {
                var prefix = ""
                if object {
                    let key = try string()
                    guard keys.insert(key).inserted, take(":") else { throw GuideLibraryError.invalid("Duplicate key/colon") }
                    prefix = key + ": "
                }
                children.append(String(repeating: "  ", count: depth + 1) + prefix + (try value(depth: depth + 1)))
            } while take(",")
            guard take(end) else { throw GuideLibraryError.invalid("JSON terminator") }
            return (object ? "{" : "[") + "\n" + children.joined(separator: ",\n") + "\n" + String(repeating: "  ", count: depth) + String(end)
        }
        let start = index
        while index < characters.count && !characters[index].isWhitespace && !",]}".contains(characters[index]) { index += 1 }
        let token = String(characters[start..<index])
        guard ["true", "false", "null"].contains(token) else { throw GuideLibraryError.invalid("Unexpected JSON token") }
        return token
    }
}
