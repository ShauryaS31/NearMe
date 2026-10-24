# P13c: Hands-free voice commands in the other app

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct night; owner device test Sun 25 Oct 10:00 |
| Depends on | P13b |
| Assignee | codex |
| Branch | task/P13c-hands-free-voice |

## Goal
Owner, from the phone test: once a guide is running with screen sharing on, the user stays in YouTube and just speaks. "What's next" (and a few other commands) triggers a fresh screen check and a spoken answer, without going back to NearMe.

## Read
AGENTS.md; `docs/ui-mockups/purple-v2/AGENT-HANDOFF.md` (read-only); tasks/P13b-observe-recheck.md (ScreenObserver, ScreenInterpreter, the coach loop); tasks/P04b-tap-to-finish.md (recognition, silence rule, voice processing). Files: `NearMe/Services/Speech/` (AnalyzerVoiceInputService, AppleSpeechFallbackService, VoiceInputRouter, NearMeAudioSession, VoiceOutputService, ElevenLabsVoiceOutput), `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Info.plist`, P13b's ScreenObserver.

Swift 6.4 rules: default arguments must not construct NearMe or test types or read MainActor statics; split long chains over tuples into typed steps; keep SwiftUI bodies small; use resolved stored properties, not optional init parameters.

## Acceptance criteria
### 1. When it runs
- [ ] Background command listening starts only when a guide starts while screen sharing is on (P13b's "sharing on" state), and the mic session is started while NearMe is in the foreground (iOS requires it). It stops when the guide ends, Stop or End session is used, or sharing stops (snapshot older than 3 s for more than 10 s). Never at any other time
- [ ] `UIBackgroundModes` gains `audio` in `NearMe/Info.plist`. The system's orange microphone indicator is visible while listening (do not try to hide it). A small "Listening for commands" line shows on the coach card while active

### 2. Audio session (do not break YouTube)
- [ ] Category `.playAndRecord` with `.mixWithOthers` and `.defaultToSpeaker` (plus Bluetooth options as today) while command listening is active, so starting the mic never pauses YouTube's audio. Use `.duckOthers` only while NearMe itself speaks, then return to mixing. Voice processing on the input as in P04b
- [ ] Pause recognition while NearMe is speaking (and 150 ms after), and while another app is playing audio (`AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint` true, observed via `silenceSecondaryAudioHintNotification`); resume when it ends. While paused, nothing from the mic is processed

### 3. Recognition: short command list only
- [ ] On-device only (P04 rules: `requiresOnDeviceRecognition = true` or SpeechAnalyzer), with the command phrases as contextual strings. Recognised text is matched only against: "what's next" (also "what next", "what now", "next step"), "next", "help", "repeat", "I'm stuck" (also "stuck"), "stop". Anything else is ignored silently (no reply, no logging of the words at `.public`). A command is accepted when a final or stable partial result equals or ends with one of the phrases (case-insensitive, punctuation ignored)
- [ ] Recognition restarts after each command and after any recogniser timeout or error, with a backoff (1 s, 2 s, 5 s, then stop and show the line "Voice commands paused, tap to resume" in NearMe)

### 4. Each command
- [ ] "what's next", "next", "help": trigger a fresh screen check (P13b ScreenObserver: use the newest snapshot, waiting up to 1.5 s for a new one) and speak the instruction for the observed page (P13b loop). "next" never blindly advances: it is the same as Done with a recheck
- [ ] "repeat": repeat the current instruction. "I'm stuck": the simpler re-prompt for the observed page. "stop": ends the guide (same as Stop the guide) and stops listening
- [ ] Each spoken answer uses ElevenLabs with the system voice fallback (P04), updates the Live Activity, and is logged under "voice" with the command name only

### 5. Tests (default run, fakes)
- [ ] Command matcher: each phrase and variant accepted, other speech ignored, punctuation and case ignored
- [ ] Lifecycle: starts only with a guide plus sharing; stops on guide end, Stop, End session, sharing lost for 10 s
- [ ] Pausing: no command accepted while NearMe speaks or while the other-audio hint is true; resumes after
- [ ] Each command triggers a recheck (fake observer) and the expected spoken line; "next" on an unchanged screen re-prompts instead of advancing
- [ ] Session options: `.mixWithOthers` while listening, `.duckOthers` only while speaking

## Verify (iPhone)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh device --current
```
iPhone check: start sharing, "play tum hi ho on youtube", stay in YouTube: the orange mic indicator shows; say "what's next": NearMe answers for the screen you are on; "repeat" and "I'm stuck" work; while the song plays, commands are ignored; "stop" ends the guide and the orange indicator goes away; YouTube's audio is never paused by NearMe starting to listen.

<!-- Dev Reports and Reviews appended below. -->
