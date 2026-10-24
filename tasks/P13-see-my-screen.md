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

## Dev Report (round 1, spike)
- Date: 2026-10-24 19:28 AEDT
- Changed files: `project.yml`; `scripts/mac-run.sh`; `NearMe/NearMe.entitlements`; `NearMeBroadcastExtension/Info.plist`; `NearMeBroadcastExtension/NearMeBroadcast.entitlements`; `NearMeBroadcastExtension/SampleHandler.swift`; `Shared/SharedScreenBridge.swift`; `NearMe/Views/Components/ScreenBroadcastButton.swift`; `NearMe/Views/Voice/CoachView.swift`; `NearMe/Views/Voice/SessionContainerView.swift`; `NearMe/Services/ScreenGuidance/ReplayKitVisionGuidanceService.swift` (removed); `NearMe/Services/ScreenGuidance/ScreenGuidanceService.swift` (obsolete comment corrected); `NearMeTests/ScreenBroadcastHeartbeatTests.swift`; this task file; `docs/LOG.md` (completion entry).
- What I did: implemented only S1-S5. Replaced the prototype frame bridge with atomic JSON containing Unix-seconds `timestamp` and video `frameCount`. A lock-protected extension timer publishes once per second, including on static screens; pause/finish cancels it and removes the heartbeat. Missing App Group access or an initial write failure ends the broadcast with a signing diagnostic. Later write failures retry and age out in the app. Removed the unused legacy JPEG/OCR consumer because its bridge APIs no longer exist. The extension never extracts or retains image/audio buffers. Added a reusable native picker sheet with truthful spike-only explanation, and a foreground debug line refreshed every second. Updated quick-build source hashing to include the new target directory.
- Acceptance criteria:
  - S1: `NearMeBroadcast` is an embedded XcodeGen `app-extension`, bundle `au.nearme.ios.broadcast`, iOS 26.5, principal class `$(PRODUCT_MODULE_NAME).SampleHandler`, broadcast-services-upload extension point and sample-buffer process mode. It uses the same Base.xcconfig, Swift 5/MainActor/approachable-concurrency/member-import settings and automatic signing as NearMeLiveActivity; `APPLICATION_EXTENSION_API_ONLY = YES`. Compilation remains a Mac gate.
  - S2: app and broadcast extension entitlements both contain `group.au.nearme.shared`. `CODE_SIGN_ENTITLEMENTS` selects the YES/NO custom setting using `CODE_SIGNING_ALLOWED`; NO selects an empty path, including when mac-run.sh forces unsigned simulator builds. No old group identifier remains in app/shared/extension Swift sources. Actual Xcode setting expansion and Personal Team provisioning remain unverified.
  - S3: Home and Coach both have "Let NearMe see my screen", opening a sheet containing `RPSystemBroadcastPickerView`, preferred extension `au.nearme.ios.broadcast`, `showsMicrophoneButton = false`. Audio callbacks are discarded. System picker display, microphone state, accessibility and taps require the iPhone check below; no programmatic private-button activation is used.
  - S4: only `screen-heartbeat.json` is written, atomically, with the two required fields; no frame/image files are written. The Debug badge says "Screen: broadcast on, last update N s ago" for a valid heartbeat at most three seconds old, otherwise "Screen: off". Pause/finish removes the file; a killed extension's leftover heartbeat expires. Added Mac unit tests for fresh/stale/future/missing/invalid heartbeats, exact JSON keys, overwriting a single small file and rejecting malformed/oversize data. Tests have not run here.
  - S5: exact signing/device procedure and fallback decision are below. Fallback is documented only, not implemented.
- Verify commands run and results:
  - `git branch --show-current`: `task/P13-see-my-screen`. Initial status contained only the owner's untracked `docs/ui-mockups/`; it was not read or edited.
  - `git diff --check`: passed (line-ending warnings only).
  - Inline `python -` checks using PyYAML and plistlib: passed target type/id/deployment/embedding, matching extension config/Swift settings, YES/NO entitlement configuration and matching App Group arrays, extension principal class/process mode, and absence of legacy group/frame/JPEG bridge references in app/shared/extension Swift sources. These are static checks, not Xcode build-setting resolution or compilation.
  - `Get-Command python,python3,swift,xcodebuild,xcodegen -ErrorAction SilentlyContinue`: Python is available; Swift, Xcode/xcodebuild and XcodeGen are not. This machine has no Swift or Xcode. Neither required Mac command nor the new XCTest cases ran; no simulator/device/build success is claimed.
  - `git diff --numstat -- docs/SPEC.md docs/PLAN.md CLAUDE.md AGENTS.md docs/ui-mockups/`: no tracked changes. Round 2 code and guide schemas remain untouched.
- Mac test steps for the owner (run from the repository root; record actual results before approving Round 2):
  1. Use the manager's committed `task/P13-see-my-screen` checkout. Run `git branch --show-current`, then `xcodebuild -version` and `xcodegen`. Use the owner's Swift 6.4/iOS 26.5-capable Xcode. Do not commit the generated project. Run `bash scripts/mac-run.sh test --current`; confirm the new `ScreenBroadcastHeartbeatTests` run as well as the existing suite. Save failures from `build/xcodebuild.log`, distinguishing existing failures from spike failures.
  2. Confirm unsigned signing settings for both targets with the following command. Both must show `CODE_SIGNING_ALLOWED = NO` and empty/absent `CODE_SIGN_ENTITLEMENTS`. The simulator build/test must not request App Group provisioning.
     ```sh
     for target in NearMe NearMeBroadcast; do
       xcodebuild -project NearMe.xcodeproj -target "$target" -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO -showBuildSettings | grep -E ' CODE_SIGNING_ALLOWED =| CODE_SIGN_ENTITLEMENTS ='
     done
     ```
  3. In Xcode > Settings > Accounts, sign in with the owner's Apple ID and identify the Personal Team. If `Config/Team.xcconfig` does not exist, run `cp Config/Team.xcconfig.example Config/Team.xcconfig`; edit the local file to set `DEVELOPMENT_TEAM` to that team's ID and retain `CODE_SIGNING_ALLOWED = YES`, `CODE_SIGN_STYLE = Automatic`, `CODE_SIGN_IDENTITY = Apple Development`. Do not commit the local file. Connect/unlock/trust the iPhone and enable Developer Mode if requested. Run `open NearMe.xcodeproj`. In Signing & Capabilities, check NearMe, NearMeBroadcast and NearMeLiveActivity use the same Personal Team and automatic signing. App Groups must include `group.au.nearme.shared` on NearMe and NearMeBroadcast; no App Group is needed on NearMeLiveActivity. Do not silently change bundle/group identifiers to bypass a signing failure.
  4. Check signed device settings, then run the required device build:
     ```sh
     for target in NearMe NearMeBroadcast; do
       xcodebuild -project NearMe.xcodeproj -target "$target" -configuration Debug -sdk iphoneos -showBuildSettings | grep -E ' CODE_SIGNING_ALLOWED =| CODE_SIGN_ENTITLEMENTS =| DEVELOPMENT_TEAM =| PRODUCT_BUNDLE_IDENTIFIER ='
     done
     bash scripts/mac-run.sh device --current
     ```
     Expect signing YES, the chosen team, and each target's real entitlements path. The build must embed `build/Build/Products/Debug-iphoneos/NearMe.app/PlugIns/NearMeBroadcast.appex`. If provisioning rejects App Groups/Personal Team, the group registration or bundle identifiers, retain the exact error from `build/xcodebuild.log`; do not call this a successful spike.
  5. If the device build signs, inspect the actual signed entitlements and embedded provisioning profiles (not just the source plist):
     ```sh
     codesign -d --entitlements :- build/Build/Products/Debug-iphoneos/NearMe.app
     codesign -d --entitlements :- build/Build/Products/Debug-iphoneos/NearMe.app/PlugIns/NearMeBroadcast.appex
     security cms -D -i build/Build/Products/Debug-iphoneos/NearMe.app/embedded.mobileprovision > build/p13-app-profile.plist
     security cms -D -i build/Build/Products/Debug-iphoneos/NearMe.app/PlugIns/NearMeBroadcast.appex/embedded.mobileprovision > build/p13-broadcast-profile.plist
     /usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.security.application-groups' build/p13-app-profile.plist
     /usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.security.application-groups' build/p13-broadcast-profile.plist
     ```
     Expect the same `group.au.nearme.shared` in both signatures and both profiles, and matching team identifiers. A successful unsigned simulator build cannot establish this.
  6. On the real iPhone, finish onboarding if needed. Home > More > Show debug info: expect `Screen: off`. Tap "Let NearMe see my screen", read the test explanation and tap the system broadcast icon. Confirm NearMe is the preselected provider and microphone capture is off/the microphone control is hidden. Cancel once: badge stays off. Reopen, tap Start Broadcast, wait for the system countdown, then return to the sheet and tap Done. Within a few seconds the badge should say `Screen: broadcast on, last update 0 s ago` or `1 s ago`, and remain fresh for at least ten seconds on a static screen.
  7. Confirm the real JSON hand-off using Xcode > Debug > Attach to Process > NearMe, then pause the app and run these LLDB expressions:
     ```text
     po SharedScreenBridge.heartbeatURL
     po SharedScreenBridge.heartbeatURL.flatMap { SharedScreenBridge.read(from: $0) }
     po SharedScreenBridge.heartbeatURL.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.deletingLastPathComponent().path) }
     ```
     Expect a non-nil App Group URL, timestamp near now, a nonnegative frame count, and `screen-heartbeat.json` with no image/movie files. Resume, change the screen, pause and read again: timestamp advances and frameCount increases. Resume promptly after inspection. This checks actual device sharing; the unit test alone cannot.
  8. Start a guide (for example type "make the writing bigger on iPhone"), enable More > Show debug info if needed, and repeat the picker check from Coach. Switch to Settings for ten seconds and return to NearMe: the badge should show a fresh heartbeat from the extension. This spike does not keep the app polling while suspended and does not advance/reopen/simplify a guide. Check the picker and Done at Accessibility XXXL and with VoiceOver; the sheet and coach should scroll with existing Stop reachable.
  9. Stop the broadcast using the iPhone screen recording control. On return to NearMe the badge must show off within one refresh (or at most about four seconds if cleanup was interrupted). Repeat start/stop and test locking/unlocking. For abrupt termination, attach Xcode to the NearMeBroadcast extension and stop that process, then return to the app; within about four seconds the stale heartbeat must show off, never indefinitely on. Record device/iOS version, signing result, picker visibility, heartbeat updates, cross-app return and stop/termination behavior.
- Not done / risks / questions:
  - Personal Team App Group eligibility and registration for these exact identifiers are the spike's unresolved gate. If App Groups cannot be signed, the proposed fallback is for the extension to send the same bounded JSON to a TCP listener at `127.0.0.1` in NearMe, without an App Group entitlement. The app would listen while guiding and remain alive in the background through the planned audio-session work. It must handle disconnect/reconnect and freshness expiry. This transport, background lifetime and device feasibility have NOT been implemented or demonstrated; manager/owner must decide after the signing result. Do not start Round 2 automatically.
  - No OCR, secret filtering, screen-state inference, auto-advance/reopen/simplify, background audio keepalive, guide-schema changes or Round 2 onboarding rewrite. Existing onboarding still says it never looks at other apps; the picker sheet explains this count-only test. Production privacy/onboarding wording needs the explicitly deferred Round 2 review before screen understanding ships.
  - The required ReplayKit APIs are used as requested. Apple's current documentation marks them deprecated; the owner's actual SDK/device remains authoritative for availability. `showsMicrophoneButton = false` hides that system control; verify the actual system state on-device. The handler ignores all audio regardless.
  - API references consulted: [Apple broadcast picker](https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview), [sample handler and serialized callbacks](https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler), [App Group entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups), [same-team signing](https://help.apple.com/xcode/mac/current/en.lproj/dev23aab79b4.html). These support the implementation approach, not successful Personal Team provisioning.

## Review (round 1, spike)
- Date: 2026-10-24 19:30 AEDT
- Verdict: PASS (static). Spike merged to main so the owner can make the signed device build. Round 2 waits for the owner's App Group result.
- NearMeBroadcast target (app-extension, ReplayKit upload, au.nearme.ios.broadcast, embedded, same xcconfig and Swift settings, extension-API-only). App Group group.au.nearme.shared entitlements for app and extension applied only when CODE_SIGNING_ALLOWED=YES (unsigned simulator builds carry none). Picker button "Let NearMe see my screen". Extension writes only a heartbeat JSON (at most 1 KB); prototype frame saving removed. Badge shows broadcast on or off with age.
- Round 2 copy (owner-approved, exact): "If you choose 'Let NearMe see my screen', NearMe reads the words on your screen, on this phone, to follow along. Nothing on your screen is recorded or sent."
