# N02: Observe and re-plan loop with completion

| Field | Value |
|---|---|
| Status | todo |
| Window | Sat 24 Oct 13:30 to 15:00 |
| Depends on | N01 |
| Assignee | codex |
| Branch | task/N02-loop |

## Goal
Guidance continues automatically as the user clicks.

## Read
AGENTS.md; docs/SPEC.md

## Acceptance criteria
- [ ] `AXObserver` on the frontmost app for kAXFocusedWindowChanged, kAXFocusedUIElementChanged, kAXValueChanged, kAXUIElementDestroyed, plus frontmost-app changes via NSWorkspace
- [ ] Debounce 400 ms, re-read, re-plan; clear stale ring immediately on change
- [ ] `SessionCoordinator` (NearMeCore, testable with fakes): states idle, listening, observing, planning, guiding, done, blocked, error; keeps the last 5 steps as context
- [ ] Completion when the model says isGoalComplete and the validator agrees nothing else is needed; speak 'Done' and clear ring
- [ ] Unit tests of the state machine with fake observer and fake planner

## Verify
```
swift test --package-path NearMeCore
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
