import AppIntents
import Foundation

/// Both targets contain metadata; LiveActivityIntent executes in the app process.
nonisolated struct StartAskNearMeIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Ask NearMe"
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = false

    @MainActor func perform() async throws -> some IntentResult {
        #if !NEARME_LIVE_ACTIVITY_EXTENSION
        await AskNearMeRuntime.shared.session.start()
        #endif
        return .result()
    }
}

nonisolated struct FinishAskNearMeIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Finish speaking"
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = false
    @Parameter(title: "Session") var sessionID: String
    init() {}
    init(sessionID: UUID) { self.sessionID = sessionID.uuidString }
    @MainActor func perform() async throws -> some IntentResult {
        #if !NEARME_LIVE_ACTIVITY_EXTENSION
        if let id = UUID(uuidString: sessionID) { AskNearMeRuntime.shared.session.finish(id: id) }
        #endif
        return .result()
    }
}

nonisolated struct StopAskNearMeIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop listening"
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = false
    @Parameter(title: "Session") var sessionID: String
    init() {}
    init(sessionID: UUID) { self.sessionID = sessionID.uuidString }
    @MainActor func perform() async throws -> some IntentResult {
        #if !NEARME_LIVE_ACTIVITY_EXTENSION
        if let id = UUID(uuidString: sessionID) { await AskNearMeRuntime.shared.session.stop(id: id) }
        #endif
        return .result()
    }
}
