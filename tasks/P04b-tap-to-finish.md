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
