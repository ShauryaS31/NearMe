import Foundation

nonisolated struct ScreenReading: Equatable, Sendable {
    nonisolated enum App: String, Sendable { case knownApp, otherApp, unknown }
    nonisolated enum Page: String, Sendable { case home, searchOpen, results, watching, prompt, otherApp, unknown }
    let app: App
    let page: Page
    let evidence: [String]
    let confidence: Double
}

/// One English rule table for the one authorised guide. OCR words are evidence,
/// never an accessibility tree, exact app identity, or proof of playback.
nonisolated enum ScreenInterpreter {
    static let signatures = ["YouTube", "Home", "Shorts", "Subscriptions", "You", "Library", "Search YouTube"]
    static let otherSignatures = [["WhatsApp", "Chats", "Updates", "Calls"], ["Settings", "General", "Accessibility", "Wi-Fi"]]
    static let pageWords: [ScreenReading.Page: [String]] = [
        .home: ["Home", "Shorts", "Subscriptions", "You", "Library"],
        .searchOpen: ["Search YouTube", "space", "return", "ABC", "123"],
        .results: ["views", "view", "ago", "channel", "Filters"],
        .watching: ["Subscribe", "Share", "Comments", "Up next"],
        .prompt: ["Sign in", "Accept all", "Reject all", "Not now", "Allow"]
    ]

    static func matches(_ text: String, word: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return clean.caseInsensitiveCompare(word) == .orderedSame
    }

    static func words(in text: String) -> Set<String> {
        Set(text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
    }

    static func songRow(in snapshot: ScreenSnapshot, song: String?) -> ScreenSnapshot.Line? {
        guard let song else { return nil }
        let wanted = words(in: song)
        guard !wanted.isEmpty else { return nil }
        let rows = snapshot.lines.filter { wanted.isSubset(of: words(in: $0.text)) && $0.box.y > 0.15 }
        return rows.min { $0.box.y < $1.box.y }
    }

    static func read(_ snapshot: ScreenSnapshot, guideID: String, song: String?) -> ScreenReading {
        guard guideID == "youtube_play_song" else { return reading(.unknown, .unknown, []) }
        let texts = snapshot.lines.map(\.text)
        func exact(_ candidates: [String]) -> [String] {
            candidates.filter { word in texts.contains { matches($0, word: word) } }
        }
        let signaturesFound = exact(signatures)
        let other = otherSignatures.map { exact($0) }.max { $0.count < $1.count } ?? []
        // Conflicting app signatures are ambiguous, not permission to guess.
        if other.count >= 2 {
            return signaturesFound.count >= 2 ? reading(.unknown, .unknown, other + signaturesFound)
                : reading(.otherApp, .otherApp, other)
        }
        let prompt = exact(pageWords[.prompt] ?? [])
        let search = exact(pageWords[.searchOpen] ?? [])
        let watching = exact(pageWords[.watching] ?? [])
        let resultCandidates = pageWords[.results] ?? []
        let results = resultCandidates.filter { word in texts.contains { words(in: $0).contains(word.lowercased()) } }
        let songFound = songRow(in: snapshot, song: song) != nil
        let hasSearch = search.contains("Search YouTube")
        let keyboardOpen = search.count >= 2 && (hasSearch || texts.contains { matches($0, word: "search") })
        let youtube = signaturesFound.count >= 2 || hasSearch || keyboardOpen || watching.count >= 3
            || (results.count >= 2 && songFound)
        if !prompt.isEmpty && (youtube || prompt.count >= 2) {
            return reading(youtube ? .knownApp : .unknown, .prompt, signaturesFound + prompt)
        }
        guard youtube else {
            return reading(.unknown, .unknown, signaturesFound + other + prompt)
        }
        if hasSearch || keyboardOpen { return reading(.knownApp, .searchOpen, signaturesFound + search) }
        if watching.count >= 2 { return reading(.knownApp, .watching, signaturesFound + watching) }
        if !results.isEmpty && (songFound || results.count >= 2) {
            return reading(.knownApp, .results, signaturesFound + results)
        }
        let home = exact(pageWords[.home] ?? [])
        if home.count >= 2 { return reading(.knownApp, .home, home) }
        return reading(.knownApp, .unknown, signaturesFound)
    }

    private static func reading(_ app: ScreenReading.App, _ page: ScreenReading.Page, _ evidence: [String]) -> ScreenReading {
        var unique: [String] = []
        for word in evidence where !unique.contains(word) { unique.append(word) }
        let confidence = unique.isEmpty ? 0 : min(0.95, 0.3 + Double(unique.count - 1) * 0.18)
        return ScreenReading(app: app, page: page, evidence: unique, confidence: confidence)
    }
}
