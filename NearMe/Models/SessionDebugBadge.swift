import Foundation

/// Understanding belongs to the user turn; reply wording and speech are separate work.
struct SessionDebugBadge {
    let understanding: BrainSource
    let modelMilliseconds: Int?
    let reply: BrainSource
    let voice: String?
    let firstAudioMilliseconds: Int?
    let sttMilliseconds: Int?
    let fallbackReason: ModelFallbackReason?

    init(understanding: BrainSource, modelMilliseconds: Int?, reply: BrainSource, voice: String?,
         firstAudioMilliseconds: Int?, sttMilliseconds: Int?, fallbackReason: ModelFallbackReason? = nil) {
        self.understanding = understanding
        self.modelMilliseconds = modelMilliseconds
        self.reply = reply
        self.voice = voice
        self.firstAudioMilliseconds = firstAudioMilliseconds
        self.sttMilliseconds = sttMilliseconds
        self.fallbackReason = fallbackReason
    }

    var lines: [String] {
        let brain = understanding == .template ? "Pending" : understanding.label
        let reason = understanding == .keywordFallback ? fallbackReason.map { " (\($0.label))" } ?? "" : ""
        let model = modelMilliseconds.map { ", \($0) ms" } ?? ""
        let template = reply == .template ? " | reply: template" : ""
        let audio = firstAudioMilliseconds.map { String(format: "%.2f", Double($0) / 1000) + " s" } ?? "pending"
        let stt = sttMilliseconds.map { "\($0) ms" } ?? "pending"
        return ["Understood: \(brain)\(reason)\(model)\(template)",
                "Voice: \(voice ?? "pending"), first audio \(audio) | STT \(stt)"]
    }

    var text: String { lines.joined(separator: "\n") }
}
