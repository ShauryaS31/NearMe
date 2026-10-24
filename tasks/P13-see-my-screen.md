# P13: "See my screen" (page awareness)

| Field | Value |
|---|---|
| Status | in_progress (round 1 = spike) |
| Window | Sat 24 Oct tonight; owner tests Sun 25 Oct 10:00; kill decision 11:00 |
| Depends on | P07e, P11 |
| Assignee | codex (main folder), then owner on a real iPhone |
| Branch | task/P13-see-my-screen |

## Goal
Owner direction (core feature): NearMe knows which screen the user is on while it guides them in another app. A screen broadcast (started by the user) reads the visible text on device, NearMe works out the app and whether the current step is done, and advances, re-opens or simplifies on its own.

## Read
AGENTS.md; docs/design/GUIDES.md; docs/design/HIG-NOTES.md rules 12, 13. Files: `NearMeBroadcastExtension/SampleHandler.swift` and `Shared/SharedScreenBridge.swift` (imported prototype source, not a target yet; note it saves frames, which must change), `project.yml`, `NearMe/Info.plist`, `Config/Base.xcconfig`, `NearMe/Services/Speech/NearMeAudioSession.swift`, `NearMe/ViewModels/TaskPlannerEngine.swift` (coach, auto-open, Live Activity publication), `NearMe/Services/Intelligence/` (PlannerModelAccess, CoachModelService, PlannerCallDeadline), `NearMe/Resources/guides/youtube_play_song.json`, `whatsapp_send_photo.json`, `scripts/validate-guides.py`, `NearMe/Views/Onboarding/HowItWorksView.swift`, `NearMe/Views/Voice/SessionContainerView.swift` (debug badge).

Swift 6.4 rules: default arguments must not construct NearMe or test types or read MainActor statics; split long chains over tuples into typed steps; keep SwiftUI bodies small; use resolved stored properties, not optional init parameters. Extension code must be extension-safe (APPLICATION_EXTENSION_API_ONLY).

## Round 1: spike (about 30 min, do ONLY this part first, then stop)
- [ ] S1. Broadcast Upload Extension target `NearMeBroadcast` in project.yml (XcodeGen `app-extension`, extension point `com.apple.broadcast-services-upload`, principal class from `NearMeBroadcastExtension/SampleHandler.swift`), bundle id `au.nearme.ios.broadcast`, iOS 26.5, embedded in NearMe, same Base.xcconfig signing and Swift settings as the other extension
- [ ] S2. App Group `group.au.nearme.shared` (replace the prototype's `group.com.nearme.shared`) in entitlements files for the app and the broadcast extension (`CODE_SIGN_ENTITLEMENTS`), only when signing is on: the unsigned simulator build in `scripts/mac-run.sh` must still build (keep entitlements out of unsigned builds or make them harmless)
- [ ] S3. In the app: a button "Let NearMe see my screen" that shows `RPSystemBroadcastPickerView` preselected to `au.nearme.ios.broadcast` (microphone off), on the coach screen and in Settings or Home
- [ ] S4. Minimal hand-off: the extension writes one small JSON heartbeat `{timestamp, frameCount}` to the App Group container every second (NO frames or images, delete the prototype's frame saving); the app reads it and the Debug badge shows "Screen: broadcast on, last update N s ago" or "Screen: off"
- [ ] S5. Dev Report: the exact owner Mac steps to confirm App Group signing with the Personal Team (device build), what to look for, and the fallback if App Groups cannot be signed: the extension sends the same JSON to the app over a loopback TCP connection (127.0.0.1, app listening while guiding and alive in the background), no entitlement needed. Do not implement the fallback in the spike

## Round 2: feature (after the owner confirms the spike; brief kept here so the plan is visible)
1. Extension: about once per second, downscale the latest frame (long side about 1000 px), run Vision `VNRecognizeTextRequest` (recognitionLevel .fast, languages en), drop secrets (password, code of 4 to 8 digits, card numbers, email addresses, phone numbers, anything in or next to a field labelled password or passcode), write `{timestamp, lines: [{text, box}]}` (normalised boxes, at most 60 lines) to the App Group. Keep peak memory well under the broadcast extension limit (about 50 MB): reuse one request, release buffers, autoreleasepool, skip frames while busy. Never save frames or images
2. App: while a guide runs and the broadcast is on, keep the app alive with the existing audio session (UIBackgroundModes audio; keep the session active, silent when not speaking), read the latest screen text every second, and determine the screen state with the on-device model (P02c rules: new session, token cap, 10 s deadline, fallback to rules) plus guide hints: which app (from `app_signature` words) and whether the current step's `expect_text` is visible
3. Guide schema: per step optional `expect_text` (text that appears when the step is done, for example "Search YouTube" after tapping the search icon) and per guide `app_signature` (words that show the app is open, for example YouTube: "Home", "Shorts", "Subscriptions", "You"). Validator and GUIDES.md updated; filled for `youtube_play_song` and `whatsapp_send_photo`
4. Behaviour: auto-advance when the current step's `expect_text` appears; if the guide's `app_signature` is absent for about 3 s, say "It looks like you're not in YouTube. Let me open it again." and re-open the app (same auto-open rules); if the screen state is unchanged for 15 s, repeat the step more simply (the existing "I'm stuck" path). Speak each change (ElevenLabs, system voice fallback) and update the Live Activity (with the Island alert)
5. Debug badge line: "Screen: <app/screen state> | step check: <expect_text seen? yes/no>"
6. Honesty (manager): when the broadcast is used, the explainer and privacy wording must be true. Change the onboarding explainer to "NearMe shows you practice copies of everyday apps, so you can learn safely. If you choose 'Let NearMe see my screen', it reads the words on your screen on this phone to follow along. Nothing is recorded or sent." and show a one-time explanation before the first broadcast with the same facts. Recognised text stays on the phone and is never logged at .public
7. Tests with fake screen-text sequences: YouTube home, search, results, playing (each step auto-advances on its expect_text); wrong app (signature absent for 3 s gives the re-open line once, not repeatedly); unchanged screen for 15 s gives the simpler step; secrets filter cases; no frames written

## Verify (Mac and iPhone)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh device --current
```

<!-- Dev Reports and Reviews appended below. -->
