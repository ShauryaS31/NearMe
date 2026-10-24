# P11: Live Activity coach (Dynamic Island step and Done)

| Field | Value |
|---|---|
| Status | changes_requested |
| Window | Sat 24 Oct evening |
| Depends on | P07b |
| Assignee | codex, then owner on a real iPhone |
| Branch | task/P11-live-activity-coach |

## Goal
While the user is inside WhatsApp (or another app) following a NearMe guide, the current step stays visible in the Dynamic Island and on the Lock Screen, with a Done button that advances NearMe's own step. Based on docs/design/UI-WIDGETS-REPORT.md Part 2 section 2 ("Live Activities and Dynamic Island").

## Read
AGENTS.md; docs/design/UI-WIDGETS-REPORT.md Part 2 section 2 and "Privacy and review considerations"; docs/design/HIG-NOTES.md rules 2, 10, 13. Files: P07 coach (`NearMe/ViewModels/` coach state, `NearMe/Views/Voice/CoachView.swift`, the coach resume logic), `NearMe/Info.plist`, `project.yml`, `Config/Base.xcconfig`, `scripts/mac-run.sh`.

Swift 6.4 rules: default arguments must not construct NearMe types or read MainActor statics; split long chains over tuples into typed steps; use resolved stored properties, not optional init parameters.

## Acceptance criteria
### 1. Targets and config
- [ ] New widget extension target `NearMeLiveActivity` in project.yml (XcodeGen `app-extension`, WidgetKit), bundle id `au.nearme.ios.liveactivity`, iOS 26.5, embedded in `NearMe`, same `Config/Base.xcconfig` (team from Team.xcconfig), same Swift settings as the app. `NSSupportsLiveActivities` = YES in `NearMe/Info.plist`
- [ ] Shared source folder `Shared/LiveActivity/` compiled into both targets: `CoachActivityAttributes: ActivityAttributes` (static: guide title, total steps, session id) and `ContentState` (step number, short instruction, revision). Total data under 4 KB; instruction truncated to 120 characters
- [ ] Simulator and device builds via `scripts/mac-run.sh` still work (the extension is built and embedded automatically)

### 1b. URL scheme and resume (owner)
- [ ] Register the URL scheme `nearme` in `NearMe/Info.plist` (`CFBundleURLTypes`, identifier `au.nearme.ios`). "Open NearMe" and "Resume" use `nearme://coach?session=<id>`; the app handles it with `.onOpenURL` and resumes that coach session at its saved step (P07 resume path). An unknown or stale session id, or a malformed URL, opens Home with no error shown. Other hosts are ignored (P10 adds `nearme://ask`). Parsing is a pure, tested function

### 2. Presentations (Live Activities HIG)
- [ ] Compact: NearMe symbol (SF Symbol `hand.raised`) and "3/6". Minimal: progress ring or "3/6". Expanded: the short instruction (`.headline`, up to 2 lines), "Done" button and "Open NearMe" link. Lock Screen: guide title, current instruction, "Done" and "Resume"
- [ ] Generic, private text only: never a person's name or a place the user said ("Open the chat" rather than "Open your chat with Mum"); use the guide's own instruction text, not the personalised rewrite
- [ ] Readable at large text; VoiceOver labels on Done ("Mark step done") and Resume; system colours; no animation beyond the system's

### 3. Lifecycle
- [ ] Start: when a coach session starts a guide, if `ActivityAuthorizationInfo().areActivitiesEnabled`; one activity at a time. Update: on every step change (from the app or from Done). End: when the guide finishes ("Done, well done" final state, dismissed after 30 s), on Stop or End session, and on app launch for any stale activity whose session no longer exists
- [ ] Done button: a `LiveActivityIntent` (`CoachDoneIntent`) with parameters session id and expected step revision. It advances NearMe's coach by one step only if the session and revision match (reject duplicates and outdated taps), persists the progress (guide id, step index, session id, revision; no user words), then updates the activity. On the last step it ends the guide. It never claims to know what happened in the other app (wording: "Done" means the user says they did it)
- [ ] Done while NearMe is not running (owner): `CoachDoneIntent` is compiled into the app target AND the extension (the extension needs it for `Button(intent:)`), so the system runs `perform()` in the app's process. `perform()` must not depend on a running coach engine or any view: it loads the saved P07 progress (guide id, step index, session id, revision) from the same store, advances it if session and revision match, saves it, and updates the activity through ActivityKit (`Activity<CoachActivityAttributes>.activities`). When NearMe is next opened (or via `nearme://coach?session=<id>`), the coach resumes at the saved step. If a coach engine is running, it observes the saved change and shows the new step. No App Group. If you find that `perform()` would run in the extension process in this setup, stop, do not add an App Group, and say so in the Dev Report
- [ ] Session id and revision are persisted with the progress (UserDefaults, still no user words)
- [ ] "Open NearMe" and "Resume" deep-link back into the coach at the current step (P07 resume path)
- [ ] No polling, no background audio, no push: updates only from app actions and the intent

### 4. Tests (default run, fakes)
- [ ] Done intent logic: matching session and revision advances; duplicate or stale revision is ignored; last step ends; state persisted is only guide id, step index, session id and revision; works with NO coach engine running (call the intent's logic directly against a fake progress store and a fake activity updater)
- [ ] URL parsing: `nearme://coach?session=<id>` gives the session; unknown, stale or malformed gives Home; other hosts ignored
- [ ] Content state builder: generic text (no person names or user places), truncation to 120 characters, "3/6" formatting

## Verify (Mac and iPhone)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
bash scripts/mac-run.sh device --current
```
iPhone check: force-quit NearMe while a guide's Live Activity is showing, tap Done in the Dynamic Island: the step advances in the activity, and opening NearMe resumes at that step; "Open NearMe" opens the same session. Then: start "help me send a photo to Mum on WhatsApp", switch to WhatsApp: NearMe auto-opens WhatsApp at step 2 and the Dynamic Island shows the NearMe symbol and "2/7"; long-press shows the step with Done; Done advances the step; the Lock Screen shows the same with Done and Resume; Resume returns to the coach at the right step; finishing or stopping the guide removes the activity; no names appear on the Lock Screen.

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)
- Date: 2026-10-24 18:32 AEDT
- Changed files: `project.yml`; `scripts/mac-run.sh`; `NearMe/Info.plist`; `NearMe/App/AppCoordinator.swift`; `NearMe/App/NearMeApp.swift`; `NearMe/Models/CoachSession.swift`; `NearMe/ViewModels/TaskPlannerEngine.swift`; `NearMe/Views/Voice/SessionContainerView.swift`; `NearMeLiveActivity/Info.plist`; `NearMeLiveActivity/NearMeLiveActivity.swift`; `Shared/LiveActivity/CoachActivityAttributes.swift`, `CoachActivityUpdater.swift`, `CoachDeepLink.swift`, `CoachDoneIntent.swift`, `CoachProgress.swift`; `NearMeTests/CoachLiveActivityTests.swift`; `NearMeTests/CoachAppOpenTests.swift`; `NearMeTests/GuidedCoachTests.swift`; this task file; `docs/LOG.md` (handoff entry).
- What I did: implemented the shared Live Activity model, widget extension, persisted revision-checked Done action, app lifecycle publication and store observation, and cold/warm coach URL delivery. Migrated P07's two-key progress to one UserDefaults record containing exactly four fields. Valid saved progress also selects the existing P07 resume path on an ordinary cold launch. No App Group, new audio/background mode, polling, push service, prototype import, or generated Xcode project.
- Acceptance criteria (implementation evidence; Swift execution and device acceptance remain pending):
  - 1 / target: added embedded `NearMeLiveActivity`, bundle ID `au.nearme.ios.liveactivity`, iOS 26.5, WidgetKit/ActivityKit/AppIntents, matching Swift settings and `Config/Base.xcconfig`. Enabled `NSSupportsLiveActivities` in the app. Team configuration is inherited unchanged.
  - 1 / shared data: both targets compile `Shared/LiveActivity`. Attributes carry guide title, total steps and session UUID; content carries step number, short instruction, revision and completion flag. The builder limits instructions to 120 characters, additionally bounds UTF-8 size, and rejects encoded attributes plus state at or above 4,096 bytes.
  - 1 / build helper: extension dependency embeds automatically; quick-build generation hashing now includes `NearMeLiveActivity`. Actual simulator/device builds have NOT been run here.
  - 1b: registered `nearme` with identifier `au.nearme.ios`; both links use `nearme://coach?session=<UUID>`. `.onOpenURL` queues delivery across onboarding/cold launch. The pure parser accepts only the current saved session, routes malformed/unknown/stale coach URLs to Home without an error, and ignores other hosts. Invalid links do not erase a valid saved guide. Resume preserves the stored session, revision and step.
  - 2 / presentations: compact has `hand.raised` and progress; minimal has progress; expanded has a two-line headline instruction, Done and Open NearMe; Lock Screen has title, instruction, Done and Resume. Extracted small views use system fonts/colors, adaptive action layouts and explicit accessibility labels, including “Mark step done.” No custom animation was added. Large-text/VoiceOver rendering needs the physical-device gate.
  - 2 / privacy: the activity builder accepts bundled editorial guide content, never the request, person, place, session rewrite or spoken announcement. Persistence has no user words. Done's accessibility hint describes the user's confirmation, not observation of the other app.
  - 3 / lifecycle: checks authorization before requesting; serializes ActivityKit changes; removes other visible activities before showing a session; publishes every saved step change, including the WhatsApp handoff and failed-open rollback. Publishes step 2 before opening WhatsApp. Ends with “Done, well done” and a 30-second dismissal policy, stops on Stop/End session, and reconciles stale activities at app launch. Completion survives interrupted speech. Re-reads saved progress after asynchronous handoff work to avoid overwriting an intent's newer step.
  - 3 / Done while not running: `CoachDoneIntent: LiveActivityIntent` is compiled into BOTH targets. Its main-actor logic loads the same app UserDefaults record, compares session/revision, saves or clears before activity publication, and enumerates `Activity<CoachActivityAttributes>.activities` through the updater. It requires no coach engine or view and awaits queued publication before returning. Apple documents app-process execution, including background launch: [LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent), [widget/Live Activity interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities). No evidence was found that this setup executes `perform()` in the extension; the brief's stop condition was not triggered. Actual force-quit behavior is NOT verified here.
  - 3 / synchronization and storage: session UUID and monotonic revision persist with guide ID and step index. The main-actor compare/save action has no suspension point. Duplicate, stale and wrong-session taps are ignored. A running engine observes saved changes and updates silently; foreground resume speaks the saved step. Last-step Done clears the saved session and finishes the activity.
  - 4: added default-run XCTest coverage with fake progress stores/activity updaters for matching/duplicate/stale/wrong-session Done, completion, no-engine execution, privacy fields, reopening persistence, migration, valid/unknown/stale/malformed URLs, ignored hosts, generic text, 120-character truncation and payload size. Integration tests cover cold and warm resume, background observation without speech, app lifecycle events, interrupted completion, and an intent racing a failed app-open callback. Existing coach tests now inject fake activity updaters and reflect the four-field record. These Swift tests are authored, NOT executed here.
- Verify commands run and results:
  - `python scripts/validate-guides.py`: PASS, “Validated 15 guides: 0 problems.”
  - Inline Python using `plistlib` and PyYAML: PASS for both plists, URL registration, Live Activity support, embedded-extension dependency, shared source membership, deployment target and Swift/config parity.
  - `git diff --check`: PASS, no whitespace errors.
  - `git branch --show-current`: `task/P11-live-activity-coach`; no main checkout, fetch, merge, or macfix integration performed. The abandoned patch was not read or applied.
  - Tool availability check: this Windows machine has no Swift or Xcode. None of the three Mac verify commands, XCTest, XcodeGen, simulator or physical-device checks ran here.
  - Git handoff: staging succeeded despite the advertised read-only `.git` restriction; no permission override was used. The commit result is reported in the final handoff, with the required log entry appended after the commit.
- Mac test steps for the owner:
  1. After the manager's commit is available, check out `task/P11-live-activity-coach` on the Mac. Run `bash scripts/mac-run.sh test --current`. Require the complete default test suite to pass, including `CoachLiveActivityTests`, `CoachAppOpenTests` and `GuidedCoachTests`.
  2. Run `bash scripts/mac-run.sh quick`, then `test -d build/Build/Products/Debug-iphonesimulator/NearMe.app/PlugIns/NearMeLiveActivity.appex`. Confirm the generated app embeds the extension. With a saved guide, run `xcrun simctl openurl booted 'nearme://coach?session=00000000-0000-0000-0000-000000000000'` and `xcrun simctl openurl booted 'nearme://coach?session=bad'`; each must show Home without an error. `xcrun simctl openurl booted 'nearme://ask'` must leave the current route unchanged.
  3. With `Config/Team.xcconfig` configured and a connected Dynamic Island iPhone, run `bash scripts/mac-run.sh device --current`, then `test -d build/Build/Products/Debug-iphoneos/NearMe.app/PlugIns/NearMeLiveActivity.appex`.
  4. Without a debugger attached, start “help me send a photo to Mum on WhatsApp.” Confirm the handoff opens WhatsApp with the Island showing the hand symbol and `2/7`. Expand it: check the generic step, Done and Open NearMe. Lock the phone: check title, instruction, Done and Resume; no Mum/name/place may appear. Done must advance one saved step. Resume/Open NearMe must open that same session and step.
  5. Start another guide, force-quit NearMe while its Live Activity is showing, and tap Done in the Island. Require the activity to advance while NearMe's UI stays closed. Reopen NearMe normally: it must resume the new step without onboarding. Repeat force-quit/Done, then use Open NearMe and Lock Screen Resume. Confirm same session and saved step. If execution is found in the extension process, stop acceptance review and report it; do not add an App Group.
  6. Finish once using activity Done and once using the in-app Done. The Island should end; the Lock Screen final state must say “Done, well done” and dismiss after 30 seconds. Start a new guide before that delay expires and confirm only its activity remains. Separately exercise Stop and End session; both remove the activity, and End session removes saved progress. Disable Live Activities in Settings and confirm guidance still works without one.
  7. Check stale cleanup: while debugging a running guide, pause in the app and run `expr -l Swift -- import Foundation`, then `expr -l Swift -- UserDefaults.standard.removeObject(forKey: "coach.progress")`. Stop and relaunch the app; the orphan activity must be dismissed. Do not edit guide JSON or add user words to defaults.
  8. On the iPhone, check compact/minimal/expanded/Lock Screen presentations with large accessibility text, Bold Text, light/dark appearance and VoiceOver. Done must announce “Mark step done”; Resume must identify the guide-return action. Verify controls remain usable and any layout clipping before accepting the task.
- Not done / risks / questions: compilation, SDK metadata extraction, signing/embedding, actual app-process wake after force-quit, and device layout/accessibility remain owner gates. The implementation follows Apple's documented process contract, not an on-device measurement. No unrelated code changes or other tasks were undertaken.

## Review (round 1)
- Date: 2026-10-24 18:40 AEDT
- Verdict: CHANGES. Config sound (extension target, embed, xcconfig signing, shared sources, NSSupportsLiveActivities, nearme scheme, no App Group); must-haves met in code (Done without engine from saved progress with session and revision checks, deep link cold and warm, generic text only, migration safe, revision races handled, tests).

Fixes:
1. Build risk: Shared/LiveActivity/CoachActivityUpdater.swift:70-72 (`Activity.request`, `ActivityAuthorizationInfo`) compiles into the extension (APPLICATION_EXTENSION_API_ONLY). Add `SWIFT_ACTIVE_COMPILATION_CONDITIONS: NEARME_LIVE_ACTIVITY_EXTENSION` (plus $(inherited)) to the extension target and keep starting activities and the full `perform()` body app-only (`#if !NEARME_LIVE_ACTIVITY_EXTENSION`); the extension copy of `CoachDoneIntent` keeps the same type and parameters with an empty `perform()` (it is only needed for `Button(intent:)`). Updating and ending existing activities may stay shared only if extension-safe; otherwise app-only too.
2. TaskPlannerEngine.swift:209: dock Stop (silence, keep the step) must not end the Live Activity. Only Stop-the-guide paths (voice "stop", End session, cancel) end it. Also make in-app step changes start the activity if none exists for the current guide (`startIfNeeded: true` in persistCoach, line 876), so a missing activity comes back. Update `testAppDoneStopAndEndPublishLifecycleEvents`.
3. TaskPlannerEngine.swift:950: `clearCoach` enqueues `.stop(nil)` when there is no guide coach, ending every activity (cuts short the 30 s final state). Only enqueue a stop for an existing guide coach id.
4. TaskPlannerEngine.swift:1014-1028: resuming the session that is already running must not tear it down and rebuild it (keeps person personalisation, no double "Welcome back"): if the URL's session equals the current coach, just show it.
5. Background launch for the intent: when the system launches NearMe in the background to run `CoachDoneIntent`, no scene work may start speaking or listening. Guard `restoreCoach` speech so it only runs when the scene is active (scenePhase .active), and never from the intent path.
6. Nits: hide "Resume" on the Lock Screen once the guide is finished (NearMeLiveActivity.swift:87); Lock Screen instruction `.body` (title stays `.headline`); if `openAppWhenRun` is deprecated, use `supportedModes` (or leave it if it is not); decode bundled guides once at launch; accept the `coach` host case-insensitively; add a test of an in-app Done racing an intent with the same revision (exactly one advance).
