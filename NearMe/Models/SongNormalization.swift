import Foundation

nonisolated enum SongNormalization {
    static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let edges = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        var song = value.trimmingCharacters(in: edges)
        let prefixes = ["can you help me", "could you", "can you", "i would like", "i want to",
                        "i want", "please", "play", "the song", "it's", "it’s", "it is", "um", "uh", "er"]
        while let prefix = prefixes.first(where: {
            song.lowercased() == $0 || song.lowercased().hasPrefix($0 + " ") || song.lowercased().hasPrefix($0 + ",")
        }) {
            song = String(song.dropFirst(prefix.count)).trimmingCharacters(in: edges)
        }
        let fillers = ["please", "thanks", "thank you", "um", "uh", "er"]
        while let filler = fillers.first(where: {
            song.lowercased() == $0 || song.lowercased().hasSuffix(" " + $0) || song.lowercased().hasSuffix("," + $0)
        }) {
            song = String(song.dropLast(filler.count)).trimmingCharacters(in: edges)
        }
        guard let cleaned = PlaceNormalization.normalize(song),
              !["this song", "a song", "song", "some music", "music", "youtube"].contains(cleaned.lowercased()),
              cleaned.count <= 160, !cleaned.contains("\""), !cleaned.contains(where: { $0.isNewline }) else { return nil }
        // Speech transcripts are often lowercase; retain deliberately supplied capitalisation.
        return cleaned == cleaned.lowercased() ? cleaned.capitalized : cleaned
    }

    static func extract(from request: String) -> String? {
        let patterns = [
            #"(?i)\bplay\s+(.+?)(?:\s+on\s+youtube\b.*|$)"#,
            #"(?i)^(.+?)\s+on\s+youtube\b"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: request, range: NSRange(request.startIndex..., in: request)),
                  let range = Range(match.range(at: 1), in: request) else { continue }
            return normalize(String(request[range]))
        }
        return nil
    }
}
