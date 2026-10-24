/// Ordinary NearMe speech is local, regardless of legacy voice preferences or
/// configured service keys. Family voice has no enabled selection path yet.
@MainActor
enum NearMeVoiceOutput {
    static func make() -> any VoiceOutputService {
        SystemVoiceOutputService()
    }
}
