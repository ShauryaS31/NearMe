import Foundation

nonisolated struct ScreenCoachInstruction: Equatable, Sendable {
    let text: String
    let stepIndex: Int?
    /// Editorial text only, never the user's song or arbitrary recognised text.
    let activityText: String
}

/// Pure state machine: time may repeat an instruction, but only current screen
/// evidence supplies a step. Done re-evaluates; it never increments a step.
nonisolated struct ScreenCoachLoop {
    nonisolated enum Question: Equatable { case description, reopen, song, playback }
    private(set) var reading: ScreenReading?
    private(set) var manual = true
    private(set) var question: Question?
    private var texts: Set<String>?
    private var lastPage: ScreenReading.Page?
    private var unchangedSince: TimeInterval = 0
    private var lastPrompt: TimeInterval = 0
    private var otherSince: TimeInterval?
    private var offeredReopen = false
    private var saidCannotSee = false
    private var hasSeenCapture = false
    private var askedSong = false
    private var previousInstruction: ScreenCoachInstruction?

    mutating func update(snapshot: ScreenSnapshot?, guideID: String, song: String?, now: TimeInterval,
                         recheck: Bool = false, simplify: Bool = false,
                         allowsSongQuestion: Bool = true) -> ScreenCoachInstruction? {
        guard guideID == "youtube_play_song" else { return nil }
        guard let snapshot, snapshot.isFresh(at: now) else {
            manual = true
            reading = nil
            texts = nil
            lastPage = nil
            question = nil
            otherSince = nil
            offeredReopen = false
            previousInstruction = nil
            guard hasSeenCapture, !saidCannotSee else { return nil }
            saidCannotSee = true
            return instruction("I can't see your screen right now.", step: nil)
        }
        let wasManual = manual
        manual = false
        hasSeenCapture = true
        saidCannotSee = false
        let current = ScreenInterpreter.read(snapshot, guideID: guideID, song: song)
        reading = current
        let changed = texts != snapshot.textSet
        let pageChanged = lastPage != current.page
        if changed { unchangedSince = now }
        texts = snapshot.textSet
        lastPage = current.page
        if pageChanged { question = nil }

        if current.page == .otherApp {
            if otherSince == nil { otherSince = now }
            guard let since = otherSince, now - since >= 3, !offeredReopen else { return nil }
            offeredReopen = true
            question = .reopen
            return instruction("It looks like you've left YouTube. Shall I open it again?", step: nil)
        }
        otherSince = nil
        offeredReopen = false
        question = nil
        let next = observedInstruction(snapshot: snapshot, reading: current, song: song,
                                       allowsSongQuestion: allowsSongQuestion)
        let actionChanged = previousInstruction != next
        if wasManual || pageChanged || (changed && actionChanged) || recheck {
            previousInstruction = next
            lastPrompt = now
            return simplify ? simpler(next, snapshot: snapshot) : next
        }
        // Do not repeat a question while the person's answer is pending.
        if question == nil, !changed, now - unchangedSince >= 15, now - lastPrompt >= 15 {
            lastPrompt = now
            return simpler(next, snapshot: snapshot)
        }
        return nil
    }

    mutating func answered() { question = nil }

    mutating func captureDidStart() { hasSeenCapture = true }

    /// Drop the cached text set immediately even if speech/input temporarily
    /// prevents delivery of the one-time manual-mode announcement.
    mutating func discardEvidence() {
        reading = nil
        texts = nil
        lastPage = nil
        previousInstruction = nil
        question = nil
        otherSince = nil
        offeredReopen = false
    }

    private mutating func observedInstruction(snapshot: ScreenSnapshot, reading: ScreenReading,
                                               song: String?, allowsSongQuestion: Bool) -> ScreenCoachInstruction {
        switch reading.page {
        case .home:
            if let search = snapshot.lines.first(where: {
                ScreenInterpreter.matches($0.text, word: "Search") || ScreenInterpreter.matches($0.text, word: "search icon")
                    || ScreenInterpreter.matches($0.text, word: "magnifying glass")
            }) {
                return instruction("Tap the magnifying glass at the \(search.box.position).", step: 1)
            }
            return instruction("Tap the magnifying glass at the top right.", step: 1)
        case .searchOpen:
            guard let song else {
                guard allowsSongQuestion else { return instruction("Type the song name.", step: 2) }
                question = .song
                if !askedSong {
                    askedSong = true
                    return instruction("Which song would you like to play?", step: 2)
                }
                return instruction("Type the song name.", step: 2)
            }
            let titleInField = snapshot.lines.contains {
                $0.box.y <= 0.15 && ScreenInterpreter.words(in: song).isSubset(of: ScreenInterpreter.words(in: $0.text))
            }
            if titleInField { return instruction("Tap search on the keyboard.", step: 3) }
            return instruction("Type \"\(song)\".", step: 2, activity: "Type the song name.")
        case .results:
            if let row = ScreenInterpreter.songRow(in: snapshot, song: song) {
                return instruction("Tap the matching song result at the \(row.box.position).", step: 4)
            }
            return instruction("Tap the first result.", step: 4)
        case .watching:
            question = .playback
            return instruction("It should be playing. Is the song playing?", step: 5,
                               activity: "Return to NearMe to confirm the song is playing.")
        case .prompt:
            if reading.evidence.contains("Not now") {
                return instruction("A sign-in box has opened. Tap \"Not now\" to close it.", step: nil)
            }
            if reading.evidence.contains("Reject all") {
                return instruction("A consent box has opened. Tap \"Reject all\" to continue without accepting optional cookies.", step: nil)
            }
            // Never choose Allow/Accept or account sign-in for the person.
            question = .description
            return instruction("A sign-in or permission box has opened. What would you like to do?", step: nil)
        case .unknown, .otherApp:
            question = .description
            return instruction("I'm not sure what's on your screen. What do you see?", step: nil)
        }
    }

    private func simpler(_ value: ScreenCoachInstruction, snapshot: ScreenSnapshot) -> ScreenCoachInstruction {
        // The existing I'm stuck fallback appends Look for <label>. Only use a
        // label actually present in this snapshot, never a memorised position.
        let labels = ["Search", "Search YouTube", "Not now", "Reject all"]
        if let label = labels.first(where: { word in
            snapshot.lines.contains { ScreenInterpreter.matches($0.text, word: word) }
        }) {
            return instruction("Take your time. Look for \"\(label)\". " + value.text,
                               step: value.stepIndex, activity: value.activityText)
        }
        return instruction("Take your time. " + value.text, step: value.stepIndex, activity: value.activityText)
    }

    private func instruction(_ text: String, step: Int?, activity: String? = nil) -> ScreenCoachInstruction {
        let display = activity ?? (text.contains("?") ? "Return to NearMe to answer." : text)
        return ScreenCoachInstruction(text: text, stepIndex: step, activityText: display)
    }
}
