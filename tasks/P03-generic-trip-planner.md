# P03: Rebrand the practice screens to a generic "Trip planner"

| Field | Value |
|---|---|
| Status | todo |
| Window | Sat 24 Oct, after P02a |
| Depends on | P02a |
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
