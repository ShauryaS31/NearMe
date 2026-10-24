# P03: Rebrand the practice screens to a generic "Trip planner"

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct, after P02a |
| Depends on | P02b |
| Assignee | codex |
| Branch | task/P03-generic-trip-planner |

## Goal
The practice walkthrough imitates a real transport brand (Melbourne). Make it a generic, unbranded "Trip planner" practice app with Sydney example places, keeping the same screens, steps, highlight and caption bar.

## Read
AGENTS.md; docs/SPEC.md; docs/design/HIG-NOTES.md rules 4 and 13. Files: `NearMe/Views/PTVSim/`, `NearMe/Views/Voice/OpeningPTVView.swift`, `NearMe/Models/PTVSimStep.swift`, `NearMe/ViewModels/PTVSimulationViewModel.swift`, `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Services/Intelligence/`, `NearMe/Services/AppLauncher/PTVLauncher.swift`, `NearMe/Models/TaksPlannerState.swift`, `NearMeTests/`.

## Acceptance criteria
- [ ] Rename types, files and folders from the brand to neutral names: the `PTVSim` folder becomes `TripPlannerPractice`; `PTV*` types become `TripPlanner*` or `Practice*` (for example `PracticeStep`, `TripPlannerPracticeViewModel`, `TripPlannerPracticeView`, `OpeningPracticeView`). Same screens, same step order, same highlight and caption bar behaviour
- [ ] The practice app's visible name is "Trip planner", with a visible "Practice" label on its screens (HIG rule 13: say it is simulated)
- [ ] Brand colours and the brand file go: system colours only (`Color.accentColor`, `.primary`, `.secondary`, `Color(.systemBackground)`, `Color(.secondarySystemBackground)`, `Color(.separator)`). No hex or RGB brand palette in the practice screens. No logos or brand marks
- [ ] Example places are Sydney: Central, Town Hall, Parramatta, Holsworthy. Spoken and on-screen examples (for example the "try saying" prompt) use "I need to get to Town Hall"
- [ ] Prompts and model instructions: no real transport brand or city; describe it as "a trip planner practice app"
- [ ] `PTVLauncher.swift` (unused; opens the real brand's app and store page) is deleted
- [ ] Tests updated to Sydney places; all tests still pass
- [ ] `git grep -n -i -E "ptv|public transport victoria|melbourne|victoria|myki|box hill|flinders"` over `NearMe/`, `Shared/`, `NearMeTests/` and `NearMeBroadcastExtension/` returns nothing
- [ ] Still true from P02a: no times, platforms or routes; DEBUG badge, Type instead and logging unchanged

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh --current
```

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)
- Date: 2026-10-24 15:25 AEDT
- Changed files: `NearMe/App/ContentView.swift`; `NearMe/Models/AppRoute.swift`, `TaksPlannerState.swift`, and `PTVSimStep.swift` renamed to `PracticeStep.swift`; `NearMe/ViewModels/PTVSimulationViewModel.swift` renamed to `TripPlannerPracticeViewModel.swift`, and `TaskPlannerEngine.swift`; `NearMe/Views/PTVSim/` renamed to `TripPlannerPractice/` with six neutral-named view files and `PTVBrand.swift` deleted; `NearMe/Views/Voice/OpeningPTVView.swift` renamed to `OpeningPracticeView.swift`, and `SessionContainerView.swift`; `NearMe/Views/Components/CaptionBubble.swift` and `ProgressDotsView.swift`; `NearMe/Services/Intelligence/FoundationModelsBrain.swift` and `KeywordFallbackBrain.swift`; `NearMe/Services/ScreenGuidance/ScreenGuidanceService.swift`; `NearMe/Services/AppLauncher/PTVLauncher.swift` deleted; `NearMeBroadcastExtension/SampleHandler.swift`; `NearMeTests/JourneyIntentTests.swift`; this task report. The completion entry belongs in `docs/LOG.md` after the commit attempt.
- What I did: Rebranded the existing walkthrough to Trip planner practice, including type/property/method names, opening copy, captions, model instructions and comments. Replaced the practice palette and caption styling with adaptive system colours; added a visible Practice label to the shared screen header and opening screen. Removed the unused launcher and the additional transport-brand mode tokens. Released the global Light Mode override for the practice flow while preserving the existing onboarding/voice appearance. Progress dots accept a colour so the opening screen uses the system accent without changing other callers.
- Acceptance criteria:
  1. Neutral names: folder, types, filenames and all call sites renamed. Four screens, seven steps, field updates, callbacks, highlight conditions and caption placement/dismissal behaviour preserved. Static comparisons confirm the walkthrough model and root view differ only by neutral renaming.
  2. Visible identity: every walkthrough screen uses the shared Trip planner header with a visible Practice label; the opening screen also names Trip planner and Practice.
  3. System colours: brand palette file deleted; practice views, opening screen and caption bar use system accent, primary/secondary, system backgrounds and separators. No fixed RGB/hex, fixed white/black or logo assets in those screens. System appearance can now reach the practice flow; rendered Light/Dark verification is pending Mac.
  4. Sydney examples: legacy intent tests and explanatory examples now use Central and Town Hall. Existing parser, resilient-brain and model-evaluation cases retain Central, Town Hall, Parramatta and Holsworthy. The spoken/visible fallback prompt uses exactly "I need to get to Town Hall".
  5. Prompts: model extraction/conversation instructions and confirmation prompt describe a trip planner practice app, with no hard-coded transport brand or city. Existing no-live-data and no-invented-facts instructions remain; user-provided places are still interpolated.
  6. Launcher: unused real-app launcher deleted, along with the obsolete future-launch comment.
  7. Tests: JourneyIntent tests updated to Sydney places; the other existing Sydney test cases retained. Tests have NOT been executed here; all-tests-pass requires the owner's Mac gate.
  8. Brand search: exact required git grep returns no output (exit 1, meaning no matches). A separate filesystem search includes all untracked renamed files and also checks the additional brand spelling; no matches. No branded source paths remain.
  9. P02a invariants: results remain three labelled example options with the existing placeholder, without actual times, platforms or routes. DEBUG badge, Type instead, speech/planner logging and model-call bounds are preserved. Swift 5/MainActor settings unchanged.
- Verify commands run and results: `git diff --check` passed. `git grep -n -i -E "ptv|public transport victoria|melbourne|victoria|myki|box hill|flinders" -- NearMe/ Shared/ NearMeTests/ NearMeBroadcastExtension/` returned no matches (exit 1). PowerShell `Get-ChildItem ... -Recurse -File | Select-String` search covered untracked files too; no matches. In-memory PowerShell assertions compared the renamed model/root view to HEAD, checked retained adaptation headers, checked system-only practice colours, and confirmed unchanged DEBUG implementation, typed-input view, diagnostics sources, build settings and protected project documents; all passed. `rg` is unavailable, so searches used Git/PowerShell. `Get-Command swift,xcodebuild,xcodegen` found none. This Windows machine has no Swift or Xcode; neither Mac verify command was run and no Swift build/test success is claimed.
- Mac test steps for the owner:
  1. After the manager has made this work available, open a Terminal at the repository root on `task/P03-generic-trip-planner`. Run `bash scripts/mac-run.sh test --current`. Require the hosted suite to pass; the real-model evaluation stays opt-in as before.
  2. Run `bash scripts/mac-run.sh --current`. This regenerates the Xcode project for the renamed files, builds and launches the simulator app. Do not commit the generated project.
  3. Complete onboarding, choose Type instead, send `hello`, and confirm the spoken/visible example is `I need to get to Town Hall`. Send that request, then answer the origin question with `Central`.
  4. Check Opening Trip planner / Practice, then follow Journey Planner, origin field, destination field, search field, Town Hall result and Search. Confirm the same sequence, field filling, highlights, bottom captions and spoken guidance; each screen must visibly say Trip planner and Practice. Results must show only the three example options and existing times placeholder, with no actual transport facts.
  5. Repeat using `to Parramatta from Town Hall` and `I wanna go from Central to Holsworthy`; verify those places propagate through the fields and captions. Confirm the DEBUG source/latency badge and Type instead / Use voice behaviour remain as before. In macOS Console, select the simulator and filter `subsystem:au.nearme.ios` to check existing voice/planner diagnostics while exercising input.
  6. While paused on a practice step, run `xcrun simctl ui booted appearance dark`, then `xcrun simctl ui booted appearance light`. Verify the header, fields, results, highlights and caption bar adapt immediately and stay readable; repeat at a large accessibility text size, with Increase Contrast and Reduce Transparency. Check the opening screen on another walkthrough and confirm the session returns normally on completion.
  7. Rerun the exact brand grep above from the repository root and require no output.
- Not done / risks / questions: Mac compile, XCTest execution, visual layout/contrast and speech checks are pending. No new tests were added for this rename/copy/style change. Existing walkthrough captions refer to From/To while the fields say Choose origin/Choose destination, and the simulated field-entry sequence remains unchanged per scope. The larger shared header needs the owner’s small-screen/large-text check. No changes to the planner architecture, live transport data or other tasks.
