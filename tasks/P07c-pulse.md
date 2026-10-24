# P07c: Target pulse, 3 cycles then static

| Field | Value |
|---|---|
| Status | in_progress |
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
- [ ] Nits from the P07b final review: the engine's starting understanding source is `.template` (badge "Pending") until the first turn, not "On-device model"; remove the unused `.practiceCard` case in TaskPlannerBrain.swift:11,19 if nothing uses it; fix rename leftovers in comments ("MARK: - HelpGuide and general coach" in TaskPlannerEngine.swift, "HelpGuide validation failed" in GuideLibrary.swift); log general stuck as "generalStuck" (CoachModelService.swift:72); map `assetsUnavailable` to "model not ready"; log a cancelled call as "cancelled", not "error"
- [ ] Tests (default run): new target gives 3 pulses then static; Repeat resets to 3; Reduce Motion gives 0; changing step resets for the new target

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
```
Mac check: each practice step's ring pulses 3 times then holds still; Repeat pulses again; with Reduce Motion the ring never moves.

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)
- Date: 2026-10-24 18:13 AEDT
- Changed files: `NearMe/Views/TripPlannerPractice/PracticeHighlight.swift`, `NearMe/Views/TripPlannerPractice/TripPlannerPracticeView.swift`, `NearMe/ViewModels/TripPlannerPracticeViewModel.swift`, `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Services/Intelligence/TaskPlannerBrain.swift`, `NearMe/Services/Intelligence/GuideLibrary.swift`, `NearMe/Services/Intelligence/CoachModelService.swift`, `NearMe/Services/Intelligence/PlannerModelAccess.swift`, `NearMeTests/SessionLayoutTests.swift`, `NearMeTests/ModelAvailabilityTests.swift`, this task file.
- What I did: Replaced the continuous opacity animation with a cancellable three-cycle sequence driven by pure highlight state. Each cycle dims to 0.76 over 0.6 seconds and returns to full opacity over 0.6 seconds; a 50 ms initial pause lets the normal ring appear first. Step identity and a published Repeat revision restart the sequence. Cancellation prevents an obsolete task from updating a replacement sequence. Applied all listed P07b nits and added default-suite regressions.
- Acceptance criteria:
  1. Three cycles then static: the helper starts at 3, decrements only after both animation legs, and stops at 0. Normal stroke remains 4 pt throughout; the finished ring is fully opaque. No `repeatForever` remains in the practice highlight. Each step recreates the highlight identity. Runtime timing awaits the Mac check.
  2. Repeat routes: dock Repeat, the spoken/typed repeat route, and direct `repeatPracticeCaption()` increment the same revision. Repeat recreates the ring from full opacity even during a cycle. Slower retains its speech-only behavior. Tests exercise all four entry paths without advancing the practice step.
  3. Accessibility: Reduce Motion produces 0 remaining pulses, forces full opacity immediately, and cancels active animation work; Repeat/new targets also stay at 0. The existing 6 pt Reduce Motion and higher-priority 8 pt Increase Contrast widths remain intact.
  4. Pure helper: `PracticeHighlightState` and `PracticePulseRequest` are nonisolated value types. New target ids and Repeat revisions reset to 3, completed cycles decrement with a zero floor, identical layout requests preserve the count, and Reduce Motion sets 0. Turning Reduce Motion off alone does not request another sequence.
  5. P07b nits: engine initialization now uses `.template` (the badge renders Pending); removed unused `.practiceCard`; renamed the engine MARK and guide validation diagnostic; general stuck logs `generalStuck`; `assetsUnavailable` maps to `modelNotReady`; cancellation has its own `cancelled` reason/outcome instead of `error`.
  6. Default-run tests: added the four required pure-state scenarios to `SessionLayoutTests`, plus Pending-before-first-turn and Repeat route coverage. Added cancellation and unavailable-assets regressions to `ModelAvailabilityTests`. These files already belong to the default NearMeTests target; no opt-in flags or project changes are needed. Tests are written, not executed here.
- Verify commands run and results: `git diff --check` passed (only an existing CRLF-to-LF normalization warning for the practice view). PowerShell source checks confirmed no `repeatForever` in the practice highlight and no listed obsolete enum/comment/diagnostic strings in app Swift files. `Get-Command swift,xcodebuild,xcodegen -ErrorAction SilentlyContinue` found none. This Windows machine has no Swift or Xcode; neither required Mac command was run and no build/test pass is claimed. Checked the test error-context initializer against [Apple's API documentation](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/context). Reviewed the diff for scope, unchanged build settings, required adaptation headers, and absence of new force unwraps or actor-isolated default arguments.
- Mac test steps for the owner:
  1. On the Mac, open Terminal in the NearMe checkout containing this handoff and run `git switch task/P07c-pulse`, then `bash scripts/mac-run.sh test --current`. Confirm the complete default suite passes, including `SessionLayoutTests` and `ModelAvailabilityTests`.
  2. Run `bash scripts/mac-run.sh quick`. In the launched app, use typed input to submit `from Central to Town Hall`. With Reduce Motion and Increase Contrast off, pause on each target: count three full opacity cycles over about 3.6 seconds, then watch at least another five seconds for a fully opaque, static normal-width ring. Advance through the practice controls.
  3. On a practice target, choose dock menu Repeat after it settles and again mid-pulse; each invocation must restart three complete cycles without changing the step. Use Type instead and submit `repeat`; then choose Speak and say `repeat` (use a connected iPhone if the simulator cannot provide speech recognition). Confirm identical ring behavior and repeated caption. Confirm Slower does not restart the ring and Stop silences speech immediately.
  4. In iOS Settings > Accessibility > Motion, turn Reduce Motion on. Return to practice, advance steps, and exercise Repeat: the ring must stay still and fully opaque at 6 pt. Also toggle Reduce Motion on during an active pulse and confirm it stops immediately.
  5. In Settings > Accessibility > Display & Text Size, turn Increase Contrast on. Check the ring remains 8 pt with Reduce Motion both on and off; pulsing changes opacity only. Restore the preferred accessibility settings afterward.
  6. Relaunch the app and reveal Debug info before submitting a request: understanding must show Pending. Submit a request and confirm the badge changes to the actual understanding source. The unit tests cover unavailable-assets and cancellation mapping without downloading model assets.
- Not done / risks / questions: Mac compilation, default test execution, visual pulse timing, accessibility rendering and real voice checks remain the owner's gate. No unrelated work or changes to the specification, plan, build settings, secrets, or generated Xcode project. Commit attempt follows this report; if the sandbox denies `.git` writes, the manager must commit the handoff.
