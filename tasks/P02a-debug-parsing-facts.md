# P02a: Debug visibility, trip parsing fixes, no invented facts

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct, now |
| Depends on | P02 |
| Assignee | codex |
| Branch | task/P02a-debug-parsing-facts |

## Goal
Fix what the P02 baseline found: make the brain and voice errors visible, parse trips correctly (first sentence and follow-up answers), and stop the app stating made-up facts.

## Read
AGENTS.md; docs/SPEC.md sections 2 and 4; tasks/P02-baseline.md "Results". Key files: `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Services/Intelligence/` (TaskPlannerBrain.swift with ResilientTaskPlannerBrain and the factory, FoundationModelsBrain.swift, KeywordFallbackBrain.swift), `NearMe/Models/JourneyIntent.swift`, `NearMe/Views/Voice/VoiceSessionView.swift`, `NearMe/Views/Voice/SessionContainerView.swift`, `NearMe/Services/Speech/VoiceInputService.swift`, `NearMe/Models/PTVSimStep.swift`, `NearMe/Views/PTVSim/PTVResultsView.swift`. Leave the transport brand naming and colours alone (that is P03).

## Acceptance criteria
### 1. Debug visibility
- [ ] Every brain answer records its source. `ResilientTaskPlannerBrain` (and the keyword-only path) reports one of: `onDeviceModel`, `onDeviceModelWithKeywordFill` (model answered, keyword backstop filled a missing slot, see 2), `keywordFallback` (model unavailable or threw). `TaskPlannerEngine` publishes the latest source
- [ ] DEBUG builds only (`#if DEBUG`): a small badge on every session screen (voice screen and guided practice screens) reading "On-device model", "On-device model + keyword fill" or "Keyword fallback". It never covers the caption bar or primary buttons, has an accessibility label, and is absent from Release builds
- [ ] `Logger(subsystem: "au.nearme.ios", category: "voice")` logs every voice input and output error with its type, NSError domain and code, and description (`privacy: .public` for those; transcripts and place names `privacy: .private`). The brain logs model errors and fallbacks with category "planner"
- [ ] The generic "Something went wrong with the microphone" message is replaced: known causes get a specific plain message (permission denied: how to allow it; no input device or audio engine failure: "NearMe can't hear the microphone right now"; recogniser unavailable: "Speech recognition isn't available right now. You can type instead."). Unknown errors keep a plain message. DEBUG builds append the error domain and code to the on-screen message
- [ ] "Type instead" button on the listening screen (SF Symbol `keyboard` plus text, 44 x 44 pt minimum). It stops listening and shows a text field with a Send button; submitting goes through exactly the same path as a spoken transcript, including pending follow-up questions (see 3). Also offered when speech or the mic is unavailable

### 2. First-sentence parsing
- [ ] Keyword brain handles "from X to Y", "to Y from X" and "I need to get to Y" (also "I wanna go from X to Y", "take me to Y", "get me to Y") with trailing punctuation and filler ("please", "thanks") stripped
- [ ] Model path: the extraction instructions say to fill origin and destination whenever both are said. After every model extraction, run the keyword parse on the same sentence and fill any slot the model left nil or empty (never overwrite a model value); the source becomes `onDeviceModelWithKeywordFill` when this happens
- [ ] Unit tests in `NearMeTests/KeywordFallbackBrainTests.swift` (replace the near-empty file) and a new `NearMeTests/FoundationModelsBrainTests.swift`, same cases for both brains: "I wanna go from Central to Holsworthy" gives origin Central and destination Holsworthy; "to Parramatta from Town Hall" gives origin Town Hall and destination Parramatta; "I need to get to Town Hall" gives destination Town Hall and origin nil. The model tests go through the resilient brain with keyword fill and call `XCTSkip` when `FoundationModelsBrain.isAvailable` is false. Compare place names case-insensitively and trimmed

### 3. Follow-up answers
- [ ] New brain method that extracts only the place name from a follow-up answer for the slot being asked. Model: a `@Generable` struct with one optional `place` field (guide: the station, suburb or place name only, nil if none is clear). Keyword: strip leading phrases ("I'm leaving from", "I'm at", "from", "to", "it's", "um", "uh", "er") and trailing filler, nil if nothing is left. The engine uses this instead of writing the raw transcript into the slot
- [ ] If the result is nil, ask once more ("Sorry, which station or suburb?" for the same slot). If still nil, say "Let's start again. Where would you like to go?" and clear the trip. Never write a raw transcript into origin or destination
- [ ] Unit tests for the keyword extractor: "I'm leaving from Central" gives Central; "um, Town Hall please" gives Town Hall; "Holsworthy." gives Holsworthy; "um" gives nil

### 4. No invented facts
- [ ] The closing practice caption no longer mentions services, timing or platforms. It says the practice is complete and what the user would do next in the real app, for example: "That's the practice done. In the real app, you'd pick a trip from this list and follow its steps. Anything else you need help with?"
- [ ] `PTVResultsView`: no times, durations or platform numbers. Rows become clearly labelled examples without facts (for example "Trip option 1", "Times show here in the real app")
- [ ] Model prompts (clarifying question and confirmation): instructions forbid stating times, platforms, routes, lines, frequencies or prices. The keyword fallback lines already comply; keep them
- [ ] `git grep -n -i -E "[0-9]{1,2}:[0-9]{2} ?(am|pm)|platform [0-9]|leaves shortly"` over `NearMe/` returns nothing

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh --current
```

<!-- Dev Reports and Reviews appended below. -->
