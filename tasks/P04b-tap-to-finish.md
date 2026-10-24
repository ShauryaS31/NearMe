# P04b: Tap to finish speaking, noise handling

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct, after P03a, before P07 |
| Depends on | P03a |
| Assignee | codex |
| Branch | task/P04b-tap-to-finish |

## Goal
In a noisy venue the user decides when they have finished speaking: tap to start, tap to stop. Auto-stop is only a backup and is driven by recognised words, not loudness, so background music cannot hold the microphone open. Echo cancellation and noise suppression are on, and NearMe never hears itself.

## Read
AGENTS.md; docs/design/HIG-NOTES.md rules 3, 9, 10, 14. Files: `NearMe/Services/Speech/AnalyzerVoiceInputService.swift`, `AppleSpeechFallbackService.swift`, `SpeechTurn.swift` (SpeechSilenceRule), `VoiceInputRouter.swift`, `VoiceInputService.swift`, `NearMeAudioSession.swift`, `ElevenLabsVoiceOutput.swift`, `VoiceOutputService.swift`, `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Views/Voice/VoiceSessionView.swift`, `NearMe/Views/Components/VoiceOrbView.swift`, `NearMeTests/`.

Swift 6.4 rule (P04a): default arguments must not construct NearMe types or read MainActor statics; take optionals and build defaults in the init body.

## Acceptance criteria
### 1. Tap to start, tap to finish
- [ ] The orb is a clear toggle. Idle: tap starts listening; label under the orb "Tap to talk". Listening: label "Listening... tap when you're done"; tap stops immediately and uses what was heard so far (final result if the recogniser delivers it within 1 s, otherwise the latest partial). Large text style for the label
- [ ] VoiceOver: idle "Start listening", listening "Stop listening"; the orb is a button with these labels and an `.isButton` trait; the animated listening effect follows Reduce Motion as today
- [ ] `VoiceInputService` gets one entry point for finishing early (for example `finishListening()`), implemented by both recogniser paths and the router, distinct from `stopListening()` (which cancels and discards)

### 2. Backup auto-stop by words, not loudness
- [ ] Replace the RMS-based `SpeechSilenceRule` end condition with a recogniser-activity rule: the turn ends when at least one word has been recognised and the transcript (partials included) has not changed for 1.5 s (one constant). Microphone loudness no longer extends or ends a turn
- [ ] Hard cap: 12 s per turn (one constant, replaces the 25 s backstop). At the cap, stop and use what was heard; if nothing, the no-words path (5)

### 3. Noise and echo
- [ ] Enable voice processing on the input before the audio engine starts: `try engine.inputNode.setVoiceProcessingEnabled(true)` in both recogniser paths (echo cancellation and noise suppression). If it throws, log it (category "voice") and continue without it. Keep the session category `.playAndRecord` with `.defaultToSpeaker` so NearMe's voice still plays from the loudspeaker (do not switch to `.voiceChat` mode if that routes output to the earpiece)
- [ ] NearMe never transcribes itself: listening starts only after voice output has fully stopped (the existing rule), plus a 150 ms settle delay after playback ends before the input tap is installed; partial results that arrive while voice output is playing are discarded
- [ ] Log per turn: voice processing on or off, end reason (tap, words settled, 12 s cap, no words), duration

### 4. Barge-in
- [ ] Tapping the orb while NearMe is speaking stops the speech at once (ElevenLabs or system voice) and starts listening; the interrupted line is not repeated. Works on the voice screen and during practice captions

### 5. No words
- [ ] If a tap, the backup rule or the cap ends a turn with no words: show and say "I didn't hear anything. Tap and try again, or type instead." with the Type instead button visible; stay idle (no automatic re-listen)

### 6. Tests (fakes, default run)
- [ ] Toggle state machine: idle, tap, listening, tap, finishing, result; second tap while finishing is ignored; barge-in from speaking goes to listening and stops output
- [ ] Backup rule with a fake clock: no end before the first word; ends 1.5 s after the last transcript change; changing partials keep it open; loudness has no effect (rule takes no audio input)
- [ ] 12 s cap returns the words heard; no-words path shows the message and does not re-listen
- [ ] Settle delay: no partial accepted while output is playing

## Verify (Mac and iPhone)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
bash scripts/mac-run.sh device --current
```
Mac checks on the iPhone in the noisy venue: tap, speak, tap: the words are captured with music in the background; tapping while NearMe speaks stops it and listens; NearMe's own voice is never transcribed; saying nothing and tapping gives the "I didn't hear anything" message.

<!-- Dev Reports and Reviews appended below. -->
