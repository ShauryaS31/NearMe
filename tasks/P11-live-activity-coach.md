# P11: Live Activity coach (Dynamic Island step and Done)

| Field | Value |
|---|---|
| Status | todo (after P07b) |
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

### 2. Presentations (Live Activities HIG)
- [ ] Compact: NearMe symbol (SF Symbol `hand.raised`) and "3/6". Minimal: progress ring or "3/6". Expanded: the short instruction (`.headline`, up to 2 lines), "Done" button and "Open NearMe" link. Lock Screen: guide title, current instruction, "Done" and "Resume"
- [ ] Generic, private text only: never a person's name or a place the user said ("Open the chat" rather than "Open your chat with Mum"); use the guide's own instruction text, not the personalised rewrite
- [ ] Readable at large text; VoiceOver labels on Done ("Mark step done") and Resume; system colours; no animation beyond the system's

### 3. Lifecycle
- [ ] Start: when a coach session starts a guide, if `ActivityAuthorizationInfo().areActivitiesEnabled`; one activity at a time. Update: on every step change (from the app or from Done). End: when the guide finishes ("Done, well done" final state, dismissed after 30 s), on Stop or End session, and on app launch for any stale activity whose session no longer exists
- [ ] Done button: a `LiveActivityIntent` carrying session id and expected step revision. It advances NearMe's coach by one step only if the session and revision match (reject duplicates and outdated taps), persists the step (guide id and step index only, as P07), then updates the activity. On the last step it ends the guide. It never claims to know what happened in the other app (wording: "Done" means the user says they did it)
- [ ] "Open NearMe" and "Resume" deep-link back into the coach at the current step (P07 resume path)
- [ ] No polling, no background audio, no push: updates only from app actions and the intent

### 4. Tests (default run, fakes)
- [ ] Done intent logic: matching session and revision advances; duplicate or stale revision is ignored; last step ends; state persisted is only guide id and step index
- [ ] Content state builder: generic text (no person names or user places), truncation to 120 characters, "3/6" formatting

## Verify (Mac and iPhone)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
bash scripts/mac-run.sh device --current
```
iPhone check: start "help me send a photo to Mum on WhatsApp", switch to WhatsApp: the Dynamic Island shows the NearMe symbol and "1/7"; long-press shows the step with Done; Done advances the step; the Lock Screen shows the same with Done and Resume; Resume returns to the coach at the right step; finishing or stopping the guide removes the activity; no names appear on the Lock Screen.

<!-- Dev Reports and Reviews appended below. -->
