// Adapted from a prior prototype, used with permission.

import Foundation

enum APIKeys {
    /// The build fills this Info.plist value from the optional Secrets.xcconfig.
    /// An empty key keeps speech-to-text on the existing Apple fallback.
    static let elevenLabsAPIKey: String =
        Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_API_KEY") as? String ?? ""

    static var hasElevenLabsKey: Bool {
        !elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
