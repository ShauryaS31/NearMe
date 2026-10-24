# P07c: Target pulse, 3 cycles then static

| Field | Value |
|---|---|
| Status | todo (right after P07b merges) |
| Window | Sat 24 Oct |
| Depends on | P07b |
| Assignee | codex |
| Branch | task/P07c-pulse |

## Goal
Owner decision (resolves HIG rule 9, no continuous pulsing): the practice target ring pulses 3 times to draw the eye, then stays still.

## Read
AGENTS.md; docs/design/HIG-NOTES.md rule 9. Files: `NearMe/Views/TripPlannerPractice/PracticeHighlight.swift`, the practice view and highlight layer, `NearMe/ViewModels/TaskPlannerEngine.swift` (repeat practice caption), `NearMeTests/SessionLayoutTests.swift`.

Swift 6.4 rules: default arguments must not construct NearMe types or read MainActor statics; keep SwiftUI bodies small.

## Acceptance criteria
- [ ] When a step's target first appears (each new step), the ring pulses exactly 3 cycles of about 1.2 s each (opacity or scale, same look as today), then stays as a static ring at its normal width. No `.repeatForever`
- [ ] Repeat (dock menu, voice command "repeat", and the practice repeat path) replays the 3 pulses on the current target
- [ ] Reduce Motion: no pulse at all, static 6 pt ring from the start; Repeat does not animate either. Increase Contrast keeps the 8 pt ring
- [ ] A small pure highlight-state helper drives it: pulses remaining = 3 for each new target id, decremented per cycle, reset to 3 by Repeat, always 0 with Reduce Motion
- [ ] Tests (default run): new target gives 3 pulses then static; Repeat resets to 3; Reduce Motion gives 0; changing step resets for the new target

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
```
Mac check: each practice step's ring pulses 3 times then holds still; Repeat pulses again; with Reduce Motion the ring never moves.

<!-- Dev Reports and Reviews appended below. -->
