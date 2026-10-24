// Adapted from a prior prototype, used with permission.

import Foundation

nonisolated enum APIKeys {
    /// The build fills this Info.plist value from the optional Secrets.xcconfig.
    /// Empty or unresolved build settings select the system voice.
    static let elevenLabsAPIKey: String =
        configuredValue("ELEVENLABS_API_KEY")

    static let elevenLabsVoiceID: String = configuredValue("ELEVENLABS_VOICE_ID")

    private static func configuredValue(_ name: String) -> String {
        let value = (Bundle.main.object(forInfoDictionaryKey: name) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.hasPrefix("$(") ? "" : value
    }

    static var hasElevenLabsKey: Bool {
        !elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
