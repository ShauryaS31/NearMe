import Foundation

@MainActor
final class VoiceSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var naturalVoiceEnabled: Bool {
        get { defaults.object(forKey: "naturalVoiceEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "naturalVoiceEnabled") }
    }
}
