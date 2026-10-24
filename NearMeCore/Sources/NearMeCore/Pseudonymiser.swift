import Foundation

/// Small, local version of the owner's detector-and-span-replacement approach.
/// Detection is heuristic; arbitrary text is not guaranteed to be anonymous.
public enum Pseudonymiser {
    /// Masks email and telephone spans without retaining a map of the originals.
    public static func mask(_ text: String) -> String {
        guard let detector = try? NSDataDetector(types:
            NSTextCheckingResult.CheckingType.link.rawValue |
            NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        ) else { return "[private]" }

        var result = text
        // Replace backwards so earlier UTF-16 ranges never shift. Detector spans
        // are disjoint, including telephone-like digits inside an email address.
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let replacement: String
            switch match.resultType {
            case .link where match.url?.scheme?.lowercased() == "mailto": replacement = "[email]"
            case .phoneNumber: replacement = "[phone]"
            default: continue
            }
            guard let range = Range(match.range, in: result) else { return "[private]" }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}
