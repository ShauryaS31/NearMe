#if DEBUG
import Foundation

nonisolated enum ScreenDebugLine {
    static func make(snapshot: ScreenSnapshot?, song: String?, now: TimeInterval) -> String {
        guard let snapshot, snapshot.isFresh(at: now), let age = snapshot.age(at: now) else { return "Screen: off" }
        let reading = ScreenInterpreter.read(snapshot, guideID: "youtube_play_song", song: song)
        let words = reading.evidence.joined(separator: " ").split(whereSeparator: \.isWhitespace).prefix(4)
        let evidence = String(words.joined(separator: " ").prefix(40))
        return "Screen: \(Int(age))s | app \(reading.app.rawValue) | page \(reading.page.rawValue) | evidence \(evidence)"
    }
}
#endif
