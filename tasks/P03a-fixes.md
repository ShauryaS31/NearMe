# P03a: Fixes from the owner's retest and phone test

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct |
| Depends on | P04 |
| Assignee | codex |
| Branch | task/P03a-fixes |

## Goal
Small fixes found while testing. More items are added here if the owner's retest of P02c, P02b and P03 finds issues.

## Read
AGENTS.md. Files: `NearMe/ViewModels/TaskPlannerEngine.swift` (place answers and suggestions), the "Did you mean" ranking function and `PracticeVocabulary` from P04, `NearMe/Views/Voice/VoiceSessionView.swift`, `NearMeTests/`.

## Acceptance criteria
### 1. Accept any place (owner decision)
- [ ] This is practice, so any destination or origin the user says is accepted (for example "Newtown"), not only the practice place list. A place answer that the place extractor returns non-nil is used as is
- [ ] Suggestions are offered only when (a) the recogniser's confidence is below the threshold, or (b) the transcript contains no recognisable place at all (the place extractor returns nil). Never because the place is outside `PracticeVocabulary`
- [ ] When offered, the screen shows the transcript ("I heard: <transcript>"), up to 2 closest matches from the practice place list as tappable buttons (only matches within the edit-distance threshold; zero buttons is fine), and a "Keep what I said" button that uses the transcript's place (or the cleaned transcript if no place was extracted). Plus "Say it again". All 44 x 44 pt, spoken question uses the real names ("Did you mean Holsworthy or Town Hall?") or "Did you say <transcript>?" when there are no close matches
- [ ] Tests (fakes): "Newtown" with high confidence is accepted without suggestions; "Holsworth" with low confidence offers Holsworthy and Keep what I said; Keep what I said fills the slot with the user's words; no-place transcript offers suggestions

### 2. "nil" is not a place (owner, from the P04 Mac check)
- [ ] The model can return the text "nil" as a place ("I need to get to Town Hall" gave origin "Nil"). Normalise every extracted place in one function used by all paths (intent extraction, place cleanup, keyword fill, suggestions): trimmed, case-insensitive "nil", "null", "none", "unknown", "n/a", "-" or empty become missing (nil). Tests: each of those strings is treated as missing; "I need to get to Town Hall" through a stub model returning origin "Nil" asks where you are starting from

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
```
Mac checks: say "from Central to Newtown": accepted, no suggestions; mumble a place: suggestions plus "Keep what I said" appear and both paths work.

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)
- Date: 2026-10-24 17:00 AEDT
- Changed files: `NearMe/Models/JourneyIntent.swift`, new `NearMe/Models/PlaceNormalization.swift`, `NearMe/Services/Intelligence/FoundationModelsBrain.swift`, `NearMe/Services/Intelligence/KeywordFallbackBrain.swift`, `NearMe/Services/Intelligence/TaskPlannerBrain.swift`, `NearMe/Services/Speech/SpeechTurn.swift`, `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Views/Voice/VoiceSessionView.swift`, new `NearMeTests/PlaceNormalizationTests.swift`, `NearMeTests/ResilientTaskPlannerBrainTests.swift`, `NearMeTests/VoiceReviewTests.swift`, and this task file.
- What I did: Moved the spoken place-answer suggestion decision after extraction; removed vocabulary membership as an acceptance gate. Added a suggestion state independent of match count, retained the extracted place for Keep what I said, and cleared that state when accepting, retrying, cancelling, or changing input mode. Added shared placeholder normalization at model, keyword, resilient-brain, intent-fill, engine, and suggestion boundaries. Updated the old ranking and suggestion tests to the new behavior and added regression coverage. Existing first-turn missing-slot questions and typed-input retry behavior are preserved.
- Acceptance criteria:
  - 1.1 Any extracted place is accepted: high-confidence spoken follow-ups use the extracted value without requiring membership in PracticeVocabulary. Tests cover Newtown as either origin or destination, and the complete first-turn request from Central to Newtown.
  - 1.2 Suggestions only for low confidence or missing extraction: the spoken follow-up gate checks confidence below the existing 0.5 threshold or a normalized nil extraction; it no longer calls containsPlace.
  - 1.3 Suggestion UI and speech: shows `I heard: <transcript>`, zero to two nearest practice names, Keep what I said, and Say it again. Each button label has a minimum 44 x 44 pt frame. Ranking filters to edit distance at most 3 before taking two; the existing prefix tie-break remains. Three preserves the existing CHATSW/Chatswood case. The spoken question uses actual suggested names, or `Did you say <transcript>?` for zero matches. Keep uses the extracted words, otherwise the transcript with edge whitespace and punctuation removed. A missing-value placeholder remains missing even when kept, and the planner asks for the slot again.
  - 1.4 Fake tests added/updated: high-confidence Newtown without suggestions; low-confidence Holsworth with Holsworthy; tapping a match; keeping Holsworth without autocorrection; no-place extraction with and without close matches; low-confidence Newtown with no matches; retry and cancellation; cleaned-transcript fallback.
  - 2.1 One normalization function: PlaceNormalization.normalize trims whitespace/newlines and treats case-insensitive nil, null, none, unknown, n/a, hyphen, and empty strings as missing. Tests cover every value, uppercased/padded variants, keyword cleanup and intent parsing, slot filling, suggestion ranking, and resilient keyword fill. A stub-model origin of Nil for `I need to get to Town Hall` is tested through the engine and resilient brain to require `Where are you starting from?`. Real place spellings are preserved.
- Verify commands run and results:
  - `git branch --show-current`: task/P03a-fixes. Initial `git status --short`: clean.
  - `git diff --check`: passed, exit 0, no output after implementation.
  - `git diff --name-only`, `git diff --numstat`, `git status --short`, and manual diff review: changes scoped to P03a; no build settings, protected project documents, secrets, or Xcode project changed. No new force unwraps.
  - `Get-Command swift,xcodebuild -ErrorAction SilentlyContinue`: neither available. This machine has no Swift or Xcode. No Swift compilation, XCTest execution, simulator check, or phone check was run; the Mac verify commands have NOT passed here.
  - `rg` is unavailable; used PowerShell Get-ChildItem, Get-Content, and Select-String for source inspection.
- Mac test steps for the owner:
  1. In the Mac repository, after the manager has made this branch available, run `git fetch origin`, `git checkout task/P03a-fixes`, and `git pull --ff-only origin task/P03a-fixes`. Confirm `git branch --show-current` prints task/P03a-fixes.
  2. Run `bash scripts/mac-run.sh test --current`. Confirm NearMeTests passes, including PlaceNormalizationTests, ResilientTaskPlannerBrainTests, VoiceReviewTests, and existing TaskPlannerEngineTests. Inspect `build/xcodebuild.log` for any failure.
  3. Run `bash scripts/mac-run.sh quick`. Verify the current checkout builds and launches.
  4. With the configured, connected iPhone, run `bash scripts/mac-run.sh device --current`. Say `from Central to Newtown`; verify practice opens with those places and no suggestions. Also request `to Town Hall`, then answer the origin question with a clear `Newtown`.
  5. Start again, request `to Town Hall`, then mumble the origin. Verify the transcript, up to two close names, Keep what I said, and Say it again. Tap a suggested name and verify the practice origin; repeat and tap Keep what I said to verify the user's words are retained. Repeat and tap Say it again to answer the same pending slot.
  6. Exercise a no-place/unclear answer with zero close matches; verify the panel and both actions remain visible, and speech says `Did you say <transcript>?`. Check the buttons using VoiceOver and accessibility Dynamic Type. Deterministic zero-match and placeholder cases are also covered by the fake tests from step 2.
- Not done / risks / questions: Mac build, tests, and phone/accessibility checks remain the owner's gate. No unrelated fixes or other task work performed.
