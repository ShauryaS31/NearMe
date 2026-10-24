# P03a: Fixes from the owner's retest and phone test

| Field | Value |
|---|---|
| Status | todo (right after P04) |
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

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
```
Mac checks: say "from Central to Newtown": accepted, no suggestions; mumble a place: suggestions plus "Keep what I said" appear and both paths work.

<!-- Dev Reports and Reviews appended below. -->
