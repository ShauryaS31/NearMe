# P04b: Tap to finish speaking, noise handling

| Field | Value |
|---|---|
| Status | changes_requested |
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


## Dev Report (round 1)
- Date: 2026-10-24 17:08 AEDT
- Changed files: `NearMe/Models/TaksPlannerState.swift`; `NearMe/Services/Speech/AnalyzerVoiceInputService.swift`, `AppleSpeechFallbackService.swift`, `SpeechTurn.swift`, `VoiceInputRouter.swift`, `VoiceInputService.swift`; `NearMe/ViewModels/TaskPlannerEngine.swift`; `NearMe/Views/Components/VoiceOrbView.swift`; `NearMe/Views/Voice/VoiceSessionView.swift`, `SessionContainerView.swift`; `NearMe/Views/TripPlannerPractice/TripPlannerPracticeView.swift`; `NearMeTests/VoiceReviewTests.swift`, `OnDeviceVoiceInputTests.swift`, `TaskPlannerEngineTests.swift`, `VoiceEngineIntegrationTests.swift`; this task file.
- What I did: Added a distinct finish operation and finishing state, replaced acoustic silence detection with transcript-change timing, enabled input voice processing, gated recognizer callbacks during output, added a cancellable playback settle interval, and wired the accessible orb on the voice and practice screens. No guide content, project settings, secrets, or protected planning documents were changed. Existing output stop implementations already stop both ElevenLabs and system speech; the engine now uses them for barge-in and invalidates the interrupted continuation.
- Acceptance criteria:
  1. Tap toggle: idle starts a turn; listening finishes it; finishing ignores repeat taps. Both recognizers stop capture and allow at most the shared 1 s final-result wait, retaining the latest partial on deadline/finalization error. Cancellation discards the turn. Router forwards finish separately from cancel. The native orb button has Start listening / Stop listening labels and an explicit isButton trait; its title-style instruction reads Tap to talk / Listening... tap when you're done. Existing Reduce Motion behavior is retained.
  2. Backup stop: SpeechSilenceRule observes transcript changes only, with one 1.5 s settling constant and one 12 s capture-cap constant. Repeated identical partials do not prolong a turn. Neither audio samples nor RMS enter the rule. Both services use the same rule and preserve words at the cap.
  3. Noise/echo: both engines attempt setVoiceProcessingEnabled(true) before installing the tap and starting capture; failures log through category voice and continue. The shared playAndRecord/defaultToSpeaker/default-mode session remains intact. The engine awaits output completion or stops it synchronously for barge-in, then waits 150 ms before calling input start. Recognizer and engine callback guards discard partials during playback/settling. Completed turns log processing on/off, trigger, outcome (including no words), and capture duration.
  4. Barge-in: the voice orb and new practice orb stop pending/current speech immediately and start listening after settling. Generation guards prevent interrupted lines/old guidance continuations from replaying. Practice barge-in returns to the voice screen while retaining journey intent.
  5. No words: the exact message "I didn't hear anything. Tap and try again, or type instead." is displayed and spoken without a debug suffix; the engine returns to idle with Type instead visible and does not automatically listen again.
  6. Tests: added default-run fake tests for tap/finish/result, ignored finishing taps, final words, cap partial/empty results, no-word idle behavior, greeting and practice barge-in, playback/settle gating, cancellation during settling, router forwarding, and fake-clock transcript settling/cap behavior. Updated obsolete no-speech auto-retry tests and input fakes. These Swift tests have NOT been executed here.
- Verify commands run and results: `git diff --check` passed (only Git line-ending notices). A Python read-only source check passed for the 15 implementation/test files: scoped paths, retained adaptation headers, all input conformances implementing finish and playback gates, voice-processing-before-tap/start ordering, shared timing usage, absence of RMS/25 s policy, and preserved loudspeaker configuration. `Get-Command python,swift,xcodebuild -ErrorAction SilentlyContinue` found Python only. This Windows machine has no Swift or Xcode; no Swift compile, XCTest, simulator, device, or requested Mac verify command was run or claimed to pass. `rg` is unavailable, so searches used PowerShell/Python.
- Mac test steps for the owner:
  1. After the manager commits these changes, use the checkout containing that commit on `task/P04b-tap-to-finish`. Run `bash scripts/mac-run.sh test --current`; require the default hosted test suite, including VoiceReviewTests and OnDeviceVoiceInputTests, to pass.
  2. Run `bash scripts/mac-run.sh quick`. Check the orb labels at large accessibility text sizes, VoiceOver Start listening / Stop listening button actions, and Reduce Motion with listening active. Check Type instead stays available after a no-words turn.
  3. Connect the configured iPhone and run `bash scripts/mac-run.sh device --current`. Grant speech/microphone access and let on-device assets prepare. With music playing in the venue, tap the orb, say "to Town Hall", then tap again; confirm the recognized words are retained and extra taps during Finishing do nothing.
  4. Speak without the second tap; confirm unchanged recognized words finish after about 1.5 s despite music. Keep changing recognized words continuously beyond 12 s; confirm capture ends at the cap and retains the words. Say nothing and tap, then separately wait silently for the cap; both must speak/display the exact no-words message and stay idle.
  5. Tap during the greeting and during a practice caption (create practice using "from Central to Town Hall"). Confirm speech stops immediately, the voice screen listens after settling, and the interrupted line is not repeated. Test with online ElevenLabs configured through the existing Secrets.xcconfig, then with the phone offline after speech assets are installed to exercise system output fallback. Confirm speaker output remains on the loudspeaker and NearMe's own line never appears in the transcript.
  6. Inspect device Console logs filtered to subsystem `au.nearme.ios`, category `voice`: verify voice-processing on/off, tap / words settled / 12 s cap triggers, no-words outcomes, and capture durations. Hardware behavior on both recognizer paths, voice-processing failure fallback, and echo/noise performance require Mac/iPhone verification; the Windows static checks cannot establish these.
- Not done / risks / questions: Mac/iPhone verification remains the owner's gate. The 12 s capture cap is checked by the existing 20 ms polling loop; decoder finalization may then take up to 1 s. Practice barge-in leaves the practice screen to show the live voice turn. No additional task was started.

## Review (round 1)
- Date: 2026-10-24 17:09 AEDT
- Verdict: CHANGES (one behaviour fix). Everything else met in code: toggle with finishing state (in TaskPlannerState ==), finishListening distinct from stopListening in both paths and the router, word-based 1.5 s rule with no audio input, 12 s cap, voice processing in both paths with .defaultToSpeaker kept, 150 ms settle and acceptsTranscript gate while output plays, no-words message stays idle, VoiceOver labels, tests.
- Manager fix already on the branch: NearMeTests/TaskPlannerEngineTests.swift:96 default argument `brain: TaskPlannerBrain = CannedEngineBrain()` (Swift 6.4 MainActor default-argument error, same as macfix 5cd50e5) now optional and built in the body.

Fix:
1. TaskPlannerEngine.userTappedToTalk sets `tripPlannerPracticeViewModel = nil`, so tapping the orb during a practice caption throws away the practice and its step (undoes P04's "Stop keeps the step"). During practice: tapping the orb while NearMe speaks stops the speech at once and keeps the current step and practice view; it starts listening on the practice screen (orb shows "Listening... tap when you're done"), and the finished transcript is handled as follows: "repeat" repeats the caption, "slower" repeats it slower, "stop" or "end" ends the practice, anything else is answered with the current step's caption (P06 adds real help). Never clear the practice view model from a tap. Add a test: tap during practice speech keeps the step and the view model.

## Dev Report (round 2)
- Date: 2026-10-24 17:11 AEDT
- Changed files: `NearMe/ViewModels/TaskPlannerEngine.swift`; `NearMe/Views/Voice/SessionContainerView.swift`; `NearMe/Views/TripPlannerPractice/TripPlannerPracticeView.swift`; `NearMeTests/VoiceReviewTests.swift`; this task file.
- What I did: Addressed Review (round 1), fix 1. An orb tap retains the same practice view model and step while stopping output immediately. The container keeps the practice view mounted throughout settling, listening, finishing, and responses. The practice orb receives the live planner state, shows the existing listening/finishing instructions, and disables repeated taps during finishing. Practice transcripts bypass journey extraction: repeat and other questions replay the current caption, slower replays it slower, and stop/end exit practice to idle. Commands ignore case and surrounding whitespace/punctuation. The visible Stop button still keeps the step. Step callbacks use the current session generation after an interruption, and practice controls cancel outstanding capture before speaking. Replaying the final caption cannot automatically finish the practice. The manager's optional test-factory defaults remain intact; no constructed NearMe/test default arguments were introduced.
- Acceptance criteria:
  1. Tap toggle: practice now stays visible and retains identity and step across start/finish; it uses the existing title-style VoiceOrbButton with Start listening / Stop listening labels, button trait, and Reduce Motion behavior. Shared finish/cancel service behavior is unchanged.
  2. Backup stop: existing 1.5 s word-settling and 12 s cap implementations are unchanged; their resulting practice transcripts use the same practice command routing.
  3. Noise/echo: voice processing, playback guards, 150 ms settle, session routing, and turn logging are unchanged. Practice uses the existing listenAndHandle path.
  4. Barge-in / review fix 1: output stops synchronously, the practice and step survive, the orb listens on that screen, and the interrupted caption is not automatically repeated. Repeat/slower/stop/end and fallback caption responses are implemented. Advancing a step still speaks its caption after barge-in.
  5. No words: the practice view displays the existing exact error message, keeps Type instead visible and the current step intact, and remains idle without restarting capture.
  6. Tests: strengthened the barge-in regression to assert model identity, a noninitial step, immediate output stop, finishing tap suppression, repeat, and subsequent step progression. Added fake tests for slower/repeat/fallback on the final step without automatic completion or brain extraction, spoken stop/end, and a no-words practice turn. Swift tests are added but unexecuted here.
- Verify commands run and results: `git diff --check` passed (line-ending notices only). A read-only Python source check passed for retained practice routing, live orb wiring, error display, adaptation headers, and the default-argument regression. `Get-Command python,swift,xcodebuild -ErrorAction SilentlyContinue` found Python only. `rg` could not execute; searches used PowerShell/Python. This Windows machine has no Swift or Xcode. No Swift compilation, XCTest, simulator, device, or Mac verify command was run or claimed to pass.
- Mac test steps for the owner:
  1. In the checkout containing this fix on `task/P04b-tap-to-finish`, run `bash scripts/mac-run.sh test --current`. Require the default hosted suite, including all VoiceReviewTests and the existing Stop-keeps-step test, to pass.
  2. Run `bash scripts/mac-run.sh quick`. Start practice with "from Central to Town Hall", advance one step, and tap the orb during its caption. Confirm speech stops immediately, the same practice screen and step remain visible, and the orb says "Listening... tap when you're done". Say "repeat", tap again, and confirm the same caption plays. Tap repeatedly during Finishing; only one response should occur. Advance a step afterward and confirm its caption plays normally.
  3. Repeat the interaction with "slower", an arbitrary question, "stop", and "end". Slower must replay at the slower rate; repeat and arbitrary questions must replay the current caption at normal rate without restarting journey planning. Spoken stop/end must leave practice and stay idle. The visible Stop button must only stop the current activity and preserve the practice step. Repeat/slower at the final step must preserve that step.
  4. Start listening during practice, say nothing, and tap to finish. Confirm the exact no-words message is displayed and spoken, Type instead remains visible, the step is retained, and capture does not restart. Check the listening/finishing labels at large accessibility text sizes, with VoiceOver, and with Reduce Motion enabled.
  5. Run `bash scripts/mac-run.sh device --current` with the configured iPhone. Repeat steps 2–4 with background music, both online ElevenLabs output and offline system output after speech assets are installed. Confirm output stops immediately and NearMe's own speech never appears in recognition.
- Not done / risks / questions: Mac/iPhone verification remains the owner's gate. Command matching intentionally covers the specified standalone words; other phrases replay the current caption until P06. No other task was started.
