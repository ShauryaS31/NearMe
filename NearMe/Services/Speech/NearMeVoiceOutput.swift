/// A private build setting explicitly selects the approved presentation voice.
/// Non-demo speech stays local; legacy preferences never select this mode.
@MainActor
enum NearMeVoiceOutput {
    static func make(demoFamilyVoice: Bool? = nil) -> any VoiceOutputService {
        if demoFamilyVoice ?? APIKeys.demoFamilyVoiceEnabled {
            return ElevenLabsVoiceOutput(demoFamilyVoice: true)
        }
        return SystemVoiceOutputService()
    }
}
