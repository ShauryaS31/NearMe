# P04: ElevenLabs voice and rough edges

| Field | Value |
|---|---|
| Status | in_progress |
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

## Dev Report (round 1)
- Date: 2026-10-24 16:11 AEDT
- Git write result: `git add -- NearMe NearMeTests tasks/P04-elevenlabs-voice.md` succeeded, but `git commit -m "P04: Add cached natural voice and strictly on-device input"` failed with `fatal: Unable to create 'C:/Users/User/Desktop/projects/NearMe/.git/index.lock': Permission denied`. Everything remains uncommitted; implementation changes are staged and this final report note is unstaged. Per the user's explicit Git-write-failure instruction, stopped here for the manager to commit. The post-commit `docs/LOG.md` line has not been appended because no commit could be created.
- Changed files: `NearMe/Info.plist`; `NearMe/Models/PracticeStep.swift`; `NearMe/Services/Shared/APIKeys.swift`; `NearMe/Services/Speech/{AppleSpeechFallbackService,VoiceInputRouter,VoiceInputService,VoiceOutputService}.swift`; new `NearMe/Services/Speech/{AnalyzerVoiceInputService,ElevenLabsVoiceOutput,VoiceAudioCache,VoiceAudioPlayer,VoiceSettings}.swift`; deleted `NearMe/Services/Speech/{ElevenLabsScribeService,AudioFileRecorder}.swift`; `NearMe/ViewModels/TaskPlannerEngine.swift`; `NearMe/Views/Components/CaptionBubble.swift`; all six Swift files in `NearMe/Views/TripPlannerPractice/`; `NearMe/Views/Voice/{OpeningPracticeView,SessionContainerView,VoiceSessionView}.swift`; new `NearMeTests/{ElevenLabsVoiceOutputTests,OnDeviceVoiceInputTests,PracticeCaptionTests,VoiceEngineIntegrationTests}.swift`; this task file.
- What I did: Replaced the default output with ElevenLabs speech plus bounded system fallback, disk caching and sequential prefetch. Removed remote voice input, added capability-gated local recognition and automatic focused typing. Centralised practice labels, made the practice content and caption one scrolling layout, and exposed Repeat, Slower, Stop, Type instead and End session. Preserved the existing audio-session configuration, build settings and planner behavior outside this task.
- Acceptance criteria (implementation and static evidence; runtime acceptance remains the owner's Mac gate):
  - 1, REST/playback: `ElevenLabsVoiceOutput` conforms to `VoiceOutputService`; sends the required POST, query, three headers and two-field JSON body. `VoiceAudioPlayer` prepares/plays with `AVAudioPlayer`, awaits delegate completion, and releases playback immediately on Stop. Playback and system-speech watchdogs cover missing OS completion callbacks.
  - 1, configuration/routing: Added the voice ID Info.plist build substitution and its `APIKeys` reader. Empty/unexpanded build settings select system speech. All assistant speech remains in the engine's `voiceOutput.speak` path, including every practice caption; the session constructs `ElevenLabsVoiceOutput`. No real key or voice ID was added.
  - 2, cache: `VoiceAudioCache` uses `Caches/NearMeVoice/<SHA-256(voice_id|model_id|text)>.mp3`, atomic writes and no network for playable cache hits. It trims oldest files first to both 200 files and 50 MB. Failed cache writes do not prevent playback.
  - 2, prefetch: The engine supplies the next caption before awaiting current-caption playback. Only one prefetch runs at once; rapid steps coalesce to the latest queued caption. Foreground speech shares an existing download of the same line. Prefetch failure is silent, and Stop clears queued work.
  - 3, fallback: Empty key/ID, `NWPathMonitor` offline state, request errors, non-2xx HTTP responses, decode/playback failure and the single 2.5-second playable-audio deadline all select `SystemVoiceOutputService`. The timeout does not await request cancellation. Late successful responses still populate the cache, while continuation/generation checks prevent late playback or a second fallback.
  - 3, visibility: Category `voice` logs cache/network/system source, fallback reason and elapsed milliseconds; line text and error descriptions are private. The existing Debug-only badge updates as each line's voice is selected. Release has no voice badge.
  - 4, audio: `NearMeAudioSession` is unchanged and remains the sole category configuration. The engine awaits speech before listening, stops capture before speaking if needed, and synchronously stops output on Cancel, End session and Type instead. Headphone removal stops output. Repeat/Slower reuse cached audio; speech-generation checks prevent a replaced final caption from starting listening over its replacement.
  - 4b, local recognition: The router checks en-AU and then the device locale. On supported iOS 26 hardware/locales it checks/downloads SpeechTranscriber assets before starting SpeechAnalyzer. Otherwise it requires a non-nil, available SFSpeechRecognizer with on-device support. Every legacy request is made by one factory with `requiresOnDeviceRecognition = true`. Removed both unused recording/upload files. Recorded audio is kept in memory for local transcription, with no server recognizer path.
  - 4b, unavailable/unsupported behavior: Unsupported locales never start capture and switch to typing with the exact language-unavailable message. Asset/runtime unavailability uses the existing recognizer-unavailable message. Both paths log the reason; the view focuses the typed field on entry. Fake capability tests cover unsupported mode, locale ordering and request privacy.
  - 4b, required searches: `git grep -n 'speech-to-text\|ElevenLabsScribe\|supportsOnDeviceRecognition$' -- NearMe/` returns no matches. `git grep -n 'requiresOnDeviceRecognition = ' -- NearMe/` returns only the request factory's `= true` assignment.
  - 4c, preference: `VoiceSettings.naturalVoiceEnabled` persists the exact UserDefaults key and defaults to true. False skips cache playback, requests and prefetch, uses system voice, and logs `natural voice off`. The preference is rechecked after pending downloads. Toggle UI remains for P05.
  - 5, matching captions: Shared `PracticeLabels` values provide the action names in views and captions, including destination station rows. Captions reflect the existing automatic field filling: after origin selection the next action is Choose destination, not an instruction to type into a non-editable field.
  - 5, readable layout: All practice/opening/caption text uses semantic Dynamic Type styles, explicitly sized icons use `@ScaledMetric`, the 480-point minimum is removed, and nested/overlay scrolling is replaced by one vertical flow with caption first and reachable primary controls. Top/tab bars stack at accessibility sizes. Accessibility XXXL requires visual confirmation on Mac/device.
  - 6, tests: Added 20 default-run XCTest cases with injected HTTP, playback, fallback, recognizer capability and shortened timeout fakes. They cover request shape, SHA-256 key, persistent cache hits, eviction limits, all specified fallback reasons, late cache-only completion, Stop during fetch/playback, playback completion, prefetch reuse/failure, natural voice off, slower cached playback, on-device requests, unsupported typing, matching captions, engine routing/prefetch and Cancel/End/Type stops. No new test uses real network or audio hardware.
- Verify commands run and results:
  - `git status --short` and `git branch --show-current`: initially clean, on `task/P04-elevenlabs-voice`; no branch switch performed.
  - `git diff --check`: passed.
  - Both required `git grep` checks above: passed with the expected empty match set and sole `= true` assignment respectively.
  - Inline Python/tree-sitter inspection: 57 Swift source/test files parsed, including Debug and Release variants of `SessionContainerView` separately. The parser does not understand conditional modifiers directly (also true for the baseline); both expanded branches parsed. This is syntax checking only, not Swift type checking or compilation.
  - Inline Python/plistlib/source assertions: passed Info.plist substitutions, one audio-session category configuration, one local recognition-request factory, no remote transcription references, task-scope shared labels, Dynamic Type sizing, whitespace including new files, and protected-doc/build-setting checks. An initial label assertion also scanned the pre-existing screen-guidance service; narrowed it to the specified practice UI/caption scope. That unrelated service was not changed.
  - `Get-Command swift,xcodebuild -ErrorAction SilentlyContinue`: neither tool exists. **This machine has no Swift or Xcode. The XCTest suite and both Mac verify commands were not run, and no build/test success is claimed.**
- Mac test steps for the owner:
  1. After the manager has committed/synchronised this checkout, run `git switch task/P04-elevenlabs-voice` on the Mac. Keep `NearMe.xcodeproj` untracked.
  2. Run `bash scripts/mac-run.sh test --current`. This regenerates the project and includes the four new test files in the ordinary hosted suite without network. Then run `bash scripts/mac-run.sh quick`. Review `build/xcodebuild.log` if either fails.
  3. Ensure `Secrets.xcconfig` contains the owner's real `ELEVENLABS_API_KEY` and `ELEVENLABS_VOICE_ID` locally, then rerun `bash scripts/mac-run.sh quick`. For the physical iPhone, with the existing local signing setup, run `bash scripts/mac-run.sh device --current`.
  4. Start a session, grant permissions, allow any supported speech-asset download, and say "travel from Central to Town Hall". Complete every practice action. Confirm the Debug badge says ElevenLabs and Console's `au.nearme.ios` / `voice` messages show output requests only, on-device input selection and no transcript text in public logs. Repeat the same flow; confirm cache-hit logs and quicker speech onset.
  5. While speech is fetching and while it is playing, separately exercise Cancel, End session and Type instead. Confirm immediate silence, no late speech, and no listening before speech has finished/stopped. In practice, exercise Repeat and Slower, including the last caption; verify no overlapping speech/listening. Unplug headphones during speech and confirm it stops.
  6. Disable Wi-Fi and cellular data (or enable airplane mode), start a new session and confirm local input still works when assets are installed, with system output and no hang. On an unsupported simulator/locale, confirm typing appears automatically with the language message and keyboard focus; Use voice must not start recording. Re-enable networking afterward.
  7. For the setting without P05 UI, pause the app in Xcode and run `expr -l Swift -- UserDefaults.standard.set(false, forKey: "naturalVoiceEnabled")` in the debug console. Resume and repeat a cached flow; confirm system voice, `natural voice off` and no new ElevenLabs requests/prefetch. Set the same key back to `true` afterward. The fake tests cover HTTP 401/500, invalid audio and delayed responses without needing real credentials for those failure cases.
  8. Set Settings > Accessibility > Display & Text Size > Larger Text to its largest accessibility size, enable Bold Text, and traverse every practice screen. Confirm the full caption, field/button labels, Search and speech/session controls can all be reached by scrolling. Check portrait/landscape, light/dark, VoiceOver focus and keyboard focus after Type instead.
- Not done / risks / questions: No P05 toggle UI, planner changes, merges or other task work. Swift API availability/type checking, audio routing on hardware, installed-asset behavior, runtime tests and visual accessibility checks remain unverified until the Mac gate. Asset downloads require connectivity, but transcription never uploads recorded speech. The existing screen-guidance service has its own unrelated Journey Planner match string and was left outside scope. Apple API signatures were checked against [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer), [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber) and [AssetInventory](https://developer.apple.com/documentation/speech/assetinventory); implementation was written in this task, without copying repository code from external sources.
