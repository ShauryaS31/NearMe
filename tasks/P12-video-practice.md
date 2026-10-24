# P12: "Video app" practice (safe, unbranded)

| Field | Value |
|---|---|
| Status | done (iPhone check pending) |
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

## Dev Report (round 1)
- Date: 2026-10-24 19:14 AEDT
- Changed files: `NearMe/Models/VideoPracticeStep.swift`; `NearMe/ViewModels/VideoPracticeViewModel.swift`; `NearMe/ViewModels/TaskPlannerEngine.swift`; `NearMe/Services/Intelligence/HelpRouter.swift`; `NearMe/Services/Intelligence/CoachModelService.swift`; `NearMe/Views/VideoPractice/VideoPracticeView.swift`, `VideoPracticeHomeView.swift`, `VideoPracticeSearchView.swift`, `VideoPracticeResultsView.swift`, `VideoPracticePlayerView.swift`, `VideoPracticeOfferView.swift`; `NearMe/Views/Components/SessionDock.swift`; `NearMe/Views/TripPlannerPractice/PracticeHighlight.swift`; `NearMe/Views/Voice/SessionContainerView.swift`; `NearMeTests/VideoPracticeTests.swift`; this task file; `docs/LOG.md` (handoff entry).
- What I did: Added a five-action video practice using the trip practice's state/view-model pattern, target anchors, highlight layer and shared dock. Added model and keyword routing plus a guide-completion offer keyed only on `youtube_play_song`. No guide resources or P07e task files were changed. The completed practice remains readable until Close or End session. Reused/adapted practice files carry the required permission header. Build settings are unchanged; new default arguments are literals/nil, and SwiftUI screens are separate small views.
- Acceptance criteria:
  1. Four screens: Home has the top-right magnifying-glass Search action; Search has an editable Song field prefilled with `Tum Hi Ho` and a return-key-style Search button/native keyboard Search action; Results has only `Example video 1` through `Example video 3`; the player has a large Play action. Focusing the prefilled Song field accepts the suggestion and enables Search; the text remains editable and any text is accepted. Actions advance in the requested order. Captions use one source for speech and display, including the exact completion line. The existing highlight layer provides the cut-out and three-cycle pulse with Reduce Motion support.
  2. Caption and dock: Both trip and video practice now use the same SessionDock caption with speaker icon, instruction and Close X. The existing speech Stop and More > Repeat/Slower/End session controls are reused. Every video screen has the shared `Video app` / `Practice` header.
  3. Unbranded: No service name, logo, real video titles, times, view counts or fixed red colour appears in the video views. They use system backgrounds and semantic text/accent colours. The shared highlight's fixed black veil was replaced with the adaptive separator colour.
  4. Router: Added `practiceVideo` to both the route and generated model choice. Keyword fallback covers the requested phrases and spelling variants; explicit trip practice takes priority over generic practice wording. A strong guide match cannot consume an explicit practice request. While the identified guide is open, `can I practise first` starts video practice before coach-command parsing.
  5. Post-guide offer: Completing `youtube_play_song` clears saved coach progress, retains the normal finished Live Activity lifecycle, and displays/speaks `Want to practise this again safely?`. Yes starts video practice; no returns Home. Buttons, typed answers and spoken answers are supported. Other guide completions retain their existing behaviour. This does not depend on the P07e guide file being present yet.
  6. Tests: Added 10 default-run XCTest methods using fake model, speech, app-opener and activity services, with an isolated synthetic guide. They cover required router phrases, model/fallback selection, trip preservation, target-label/caption contracts, three-cycle/Reduce Motion state, arbitrary song text, completion speech, Repeat/Slower/Stop, stale callbacks, both offer responses, typed/spoken replies, mid-guide practice and cancellation. These tests have NOT been executed here.
  7. Mac check text: The numbered checks below explicitly require a visible dock, caption bar and highlight with exactly three pulses at each of the five practice steps.
- Verify commands run and results:
  - `git diff --check`: passed, no whitespace errors.
  - `git grep -n -i youtube -- NearMe/Views/VideoPractice/`: no matches. Because the new files are not staged yet, also scanned every video-view file directly with PowerShell and Python: no branding, fixed red or hex colours.
  - Python source check over all 15 changed/new Swift files: newline/whitespace checks passed; new-file force-unwrap scan passed. This is a source check, not a Swift compiler or runtime test.
  - `Get-Command python,swift,xcodebuild -ErrorAction SilentlyContinue`: Python found; Swift and Xcode tools absent. This Windows machine has no Swift or Xcode. Neither Mac verification command was run; no build/test success is claimed.
- Mac test steps for the owner:
  1. In the Mac checkout of `task/P12-video-practice`, run `bash scripts/mac-run.sh test --current`. Confirm the 10 `VideoPracticeTests` methods and existing router, coach, practice and dock tests pass. XcodeGen includes the new files automatically.
  2. Run `bash scripts/mac-run.sh quick` to build and launch the current checkout. Use typed help to request `practise playing a song`; repeat with `can I practise first` and `practise youtube`. Each must open Video app practice without origin/destination questions. Request `I want to practise planning a train trip` separately and confirm the trip flow still asks its normal journey questions.
  3. Walk through all five targets: Home Search; Song; Search; Example video 1; Play. Before tapping each target, wait at least four seconds. At EVERY step verify the dock, speaker/instruction/Close caption bar, dimmed surroundings, target cut-out and visible ring; the ring must pulse exactly three times and then remain static. Check that the spoken text matches the caption. Check the top-right Home magnifying glass and visible Video app / Practice labels.
  4. On Song, check the `Tum Hi Ho` prefill, then replace it with arbitrary text. Search with the native keyboard key on one run and the visible return-style Search button on another. Confirm only the example rows appear, with no titles, durations or view counts. Tap Example video 1, then Play; confirm the exact completion line stays visible and is spoken, without playing media or opening another app. Close X returns Home.
  5. At a practice step use More > Repeat: the same instruction repeats and the ring restarts three pulses. Use More > Slower: the same instruction is spoken more slowly. During speech tap Stop: audio stops immediately and the step remains. End session or Close must leave no delayed speech. Repeat these checks on trip practice to verify the shared caption/veil change.
  6. Check light/dark appearance, large accessibility text, Increase Contrast, VoiceOver and the keyboard on a small iPhone simulator/device. Captions must scroll rather than truncate; controls and the target must remain reachable. With Reduce Motion enabled, each target and Repeat must show a static ring with no pulse. Verify the adaptive veil remains visible in both appearances.
  7. After P07e is merged, complete the real `youtube_play_song` guide using Done on its final step. Confirm the exact offer is shown/spoken. Test Yes and No buttons, typed `yes please` / `no thanks`, and the same spoken answers via the microphone. Yes opens video practice; No returns Home. While that guide is still open, say/type `can I practise first` and confirm video practice starts. Complete a different guide and confirm it returns Home without this offer. Before P07e merges, the default fake-guide tests exercise this integration by id.
- Not done / risks / questions: Mac compilation, XCTest execution and visual/device checks remain the owner's gate. P07e's guide content is deliberately outside this task; the manager should review shared engine/router edits when combining branches. The existing log records prior failures in SessionLayoutTests and VoiceReviewTests; those unrelated failures were not investigated here. The shared caption chrome and adaptive veil need the trip regression check above. No merge or additional task was started.

## Review (round 1)
- Date: 2026-10-24 19:17 AEDT
- Verdict: PASS (static, one urgent round). Merged to main after P07e (owner order).
- Four unbranded practice screens on the trip practice engine (highlight with 3-cycle pulse, dim, dock, caption bar), "Video app" with a Practice label, no YouTube name or red; practiceVideo route (model and keywords); "Want to practise this again safely?" after youtube_play_song. Default-argument scan clean.
- Merge with main (P07e) resolved by the manager: one router prompt with both the practiceVideo rule and song extraction; receive() handles the pending song answer first, then the practice offer, then "practise" during the YouTube guide; acknowledgement guard keeps isPractising, offersVideoPractice and pendingSong. Every HelpRoute switch handles practiceVideo.
