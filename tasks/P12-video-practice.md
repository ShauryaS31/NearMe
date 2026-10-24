# P12: "Video app" practice (safe, unbranded)

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct, finish tonight even after 19:55 |
| Depends on | P11 (merge after P07e) |
| Assignee | codex (Lane B, worktree ../NearMe-p12) |
| Branch | task/P12-video-practice |

## Goal
A safe practice copy of a generic video app so the user can rehearse finding and playing a song, reusing the trip planner practice engine, look and behaviour.

## Read
AGENTS.md; docs/design/HIG-NOTES.md rules 4, 9, 13. Files: the trip practice (`NearMe/Views/TripPlannerPractice/` incl. PracticeHighlight and the highlight layer, `NearMe/Models/PracticeStep.swift`, `NearMe/ViewModels/TripPlannerPracticeViewModel.swift`), `NearMe/Views/Components/SessionDock.swift`, `NearMe/Views/Voice/SessionContainerView.swift`, `NearMe/Services/Intelligence/HelpRouter.swift` (HelpRoute, keyword fallback), `NearMe/ViewModels/TaskPlannerEngine.swift` (practice start, coach finish), `NearMeTests/`.

Swift 6.4 rules: default arguments must not construct NearMe or test types or read MainActor statics; split long chains over tuples into typed steps; keep SwiftUI bodies small (extract subviews); use resolved stored properties, not optional init parameters.

## Acceptance criteria
- [ ] Four practice screens in `NearMe/Views/VideoPractice/`, reusing the trip practice structure (step model, view model pattern, target anchors, `PracticeHighlight` ring with the 3-cycle pulse, dim with cut-out, dock, Stop/Repeat/Slower, captions spoken and shown): (1) home with a search icon (magnifyingglass) at the top right, (2) search screen with a text field and keyboard-style search action, (3) results list (example rows labelled "Example video 1" and so on, no real titles, no times or view counts), (4) video screen with a large play button. Steps: tap search, type the song (any text accepted; the example "Tum Hi Ho" is prefilled as the suggestion), tap search, tap the first result, tap play. Completion line: "That's the practice done. In the real app you'd do the same steps."
- [ ] Bottom caption bar exactly like the trip practice (speaker icon, step text, close X) and the same dock; visible "Practice" label and the app name "Video app"
- [ ] Unbranded: neutral system colours only (accentColor, systemBackground, secondarySystemBackground, separator), no YouTube name, logo or red anywhere in these screens (`git grep -n -i "youtube"` over `NearMe/Views/VideoPractice/` returns nothing)
- [ ] Router: a new practice route (for example `practiceVideo`) chosen for "practise playing a song", "can I practise first", "practise youtube" and similar (model choice plus keyword fallback); trip practice phrases still go to the trip practice; "can I practise first" right after a YouTube guide was offered goes to the video practice
- [ ] After the YouTube guide (`youtube_play_song`, from P07e) finishes, NearMe asks "Want to practise this again safely?"; yes starts the video practice, no returns Home. If P07e is not on main yet when you start, implement the offer keyed on the guide id string `youtube_play_song` (it will exist after merge)
- [ ] Tests (default run, fakes): router phrases above; every video practice step has a target label present on its screen; completion line; the offer after the YouTube guide
- [ ] Mac check text: each video practice step shows the dock, a visible highlight that pulses 3 times, and the caption bar

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
```

<!-- Dev Reports and Reviews appended below. -->
