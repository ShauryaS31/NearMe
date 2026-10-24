# P04: ElevenLabs voice and rough edges

| Field | Value |
|---|---|
| Status | todo (starts after the owner's Mac check of P02c, P02b and P03 passes) |
| Window | Sat 24 Oct |
| Depends on | P03 |
| Assignee | codex |
| Branch | task/P04-elevenlabs-voice |

## Goal
Every spoken line uses a natural ElevenLabs voice, feels instant thanks to caching and prefetch, and falls back to the system voice without ever hanging. Close the two rough edges left by P03.

## Read
AGENTS.md; docs/SPEC.md section 4; docs/design/HIG-NOTES.md rules 2, 7, 14. Files: `NearMe/Services/Speech/VoiceOutputService.swift`, `NearMeAudioSession.swift`, `VoiceInputRouter.swift`, `NearMe/Services/Shared/APIKeys.swift`, `NearMe/Info.plist`, `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/ViewModels/TripPlannerPracticeViewModel.swift`, `NearMe/Models/PracticeStep.swift`, `NearMe/Views/TripPlannerPractice/`, `NearMe/Views/Voice/SessionContainerView.swift` (Debug badge).

## Acceptance criteria
### 1. ElevenLabs text to speech
- [ ] `ElevenLabsVoiceOutput` conforms to `VoiceOutputService`: `POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128`, headers `xi-api-key`, `Content-Type: application/json`, `Accept: audio/mpeg`, body `{"text": <line>, "model_id": "eleven_flash_v2_5"}`. Plays the mp3 with `AVAudioPlayer`; `speak` returns when playback finishes; `stop()` stops at once
- [ ] Key and voice id come from Info.plist: add `ELEVENLABS_VOICE_ID` = `$(ELEVENLABS_VOICE_ID)` to `NearMe/Info.plist` and read it in `APIKeys` like the key. No literal keys or ids in code
- [ ] Every assistant line and every practice caption goes through it (the engine already routes all speech through `voiceOutput.speak`; keep it that way)

### 2. Cache and prefetch
- [ ] Audio cached on disk under `Caches/NearMeVoice/`, file name = SHA-256 of `voice_id|model_id|text`. A cache hit plays without any network call
- [ ] While a practice caption plays, the next step's caption is fetched into the cache (prefetch). At most one prefetch in flight; failures are silent
- [ ] Cache is capped (for example 200 files or 50 MB, oldest removed first)

### 3. Fallback and visibility
- [ ] Falls back to the existing `SystemVoiceOutputService` (AVSpeechSynthesizer) automatically when: key or voice id is empty, the device is offline (`NWPathMonitor`), the request fails or returns a non-2xx status, the audio cannot be decoded, or no playable audio is available within 2.5 s of `speak` (one constant). A response that arrives after the 2.5 s cut-off is still written to the cache for next time but not played
- [ ] `Logger` category "voice": for each line, which voice spoke (ElevenLabs cache hit, ElevenLabs network, System voice) with the fallback reason and ms. Line text only at `privacy: .private`
- [ ] The Debug badge also shows the voice of the last line: "ElevenLabs" or "System voice" (Debug builds only)

### 4. Audio session
- [ ] Keep the single existing audio session configuration (`NearMeAudioSession`); no second session or category change per line
- [ ] Never speak and listen at the same time: listening starts only after `speak` has returned or been stopped; Cancel, End session and Type instead stop voice output at once

### 4b. Voice input on-device only (owner decision)
- [ ] `VoiceInputRouter` always uses on-device Apple speech (`requiresOnDeviceRecognition = true`); the ElevenLabs speech-to-text path is removed, so recorded speech never leaves the phone. Delete `ElevenLabsScribeService.swift` and `AudioFileRecorder.swift` if nothing else uses them. If on-device recognition is unavailable, show the existing "Speech recognition isn't available right now. You can type instead." message; never fall back to a server
- [ ] Apple speech is strictly on-device, so audio never goes to Apple's servers either. Today `AppleSpeechFallbackService.swift:51` sets `requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition`, which silently uses Apple's servers when on-device is unsupported: change it to always `true`. Use `SpeechAnalyzer` with `SpeechTranscriber` (on-device by design) where available on iOS 26+, otherwise `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`
- [ ] Before listening, check on-device support for the locale (`en-AU`, then the device locale): `SFSpeechRecognizer(locale:)` non-nil, `isAvailable` and `supportsOnDeviceRecognition`, or `SpeechTranscriber` supports the locale and its on-device assets are installed (request the asset download if missing). If unsupported, do not start the recognizer: switch straight to Type instead (text field shown, focus in it) with the message "Speech recognition on this phone isn't available for your language yet. You can type instead." Log the reason (category "voice")
- [ ] Unit test (fake recognizer capability): unsupported locale gives typing mode and never starts recognition; every recognition request built has `requiresOnDeviceRecognition == true`
- [ ] `git grep -n "speech-to-text\|ElevenLabsScribe\|supportsOnDeviceRecognition$"` over `NearMe/` returns nothing, and `git grep -n "requiresOnDeviceRecognition = "` shows only `= true`

### 4c. Natural voice setting (logic only; the toggle UI comes in P05)
- [ ] `VoiceSettings.naturalVoiceEnabled` (UserDefaults key `naturalVoiceEnabled`, default true). When false, ElevenLabs is never called (no speak, no prefetch) and every line uses the system voice; the voice log says "natural voice off"

### 5. Rough edges
- [ ] Captions use exactly the same strings as the practice screens' field and button labels (for example "Choose origin", "Choose destination"): define each label once and use it in both the view and the caption
- [ ] Practice screens (`NearMe/Views/TripPlannerPractice/`, `OpeningPracticeView.swift`): Dynamic Type text styles only (no `.font(.system(size:))` for text; icons via `@ScaledMetric`), no fixed heights on text containers (remove `.frame(minHeight: 480)`), content scrolls at Accessibility XXXL with the caption bar and primary controls reachable

### 6. Tests (default run, no network)
- [ ] Cache key and cache hit, fallback decision for each reason (empty key, offline, HTTP 401/500, timeout) and caption-equals-label, using fakes (inject a URLSession protocol stub and a clock or timeout parameter)

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
```
Mac checks: voice input still works with the key present (on-device; no ElevenLabs speech-to-text in the planner or voice logs); steps spoken in the ElevenLabs voice (needs `ELEVENLABS_API_KEY` and `ELEVENLABS_VOICE_ID` in Secrets.xcconfig); a second run of the same flow starts speaking faster (cache); Wi-Fi off gives the system voice with no hang; the largest text size is usable on the practice screens.

<!-- Dev Reports and Reviews appended below. -->
