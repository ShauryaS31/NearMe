# P02a: Debug visibility, trip parsing fixes, no invented facts

| Field | Value |
|---|---|
| Status | changes_requested |
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

## Dev Report (round 1)
- Date: 2026-10-24 14:45 AEDT
- Changed files: `NearMe/Services/Intelligence/TaskPlannerBrain.swift`, `FoundationModelsBrain.swift`, `KeywordFallbackBrain.swift`; `NearMe/ViewModels/TaskPlannerEngine.swift`; `NearMe/Views/Voice/VoiceSessionView.swift`, `SessionContainerView.swift`; `NearMe/Services/Speech/VoiceInputService.swift`, `VoiceInputRouter.swift`, `AppleSpeechFallbackService.swift`, `AudioFileRecorder.swift`, `ElevenLabsScribeService.swift`, `NearMeAudioSession.swift`, `VoiceOutputService.swift`; `NearMe/Models/PTVSimStep.swift`; `NearMe/Views/PTVSim/PTVResultsView.swift`; `NearMeTests/KeywordFallbackBrainTests.swift`, `FoundationModelsBrainTests.swift`, `ResilientTaskPlannerBrainTests.swift`, `TaskPlannerEngineTests.swift`, `VoiceDiagnosticsTests.swift`; this task report. The requested log entry follows the commit attempt.
- What I did: Added source-bearing brain answers, a DEBUG session badge, structured voice/planner diagnostics, actionable voice error messages, and typed input through the same transcript handler as speech. Added keyword slot backfill and dedicated follow-up place extraction with one retry before clearing the trip. Removed fabricated practice facts. Protected input/output cancellation and stale audio callbacks when switching to typing. Added 16 test methods (20 total including the existing four).
- Acceptance criteria (implemented; runtime verification is pending the owner's Mac):
  1. Debug/source: Every brain method returns `BrainAnswer` with one of the three required sources; the resilient wrapper records keyword fill or fallback, and the engine publishes `latestBrainSource`. Before the first answer, the badge shows the configured brain source.
  2. Debug/badge: The common session container reserves a top safe-area inset for the exact source label and an accessibility label, including voice, opening and every guided screen. The entire badge modifier is inside `#if DEBUG`; no caption or button overlay was added.
  3. Debug/logging: `Logger(subsystem: "au.nearme.ios", category: "voice")` records error type, NSError domain/code and description with public privacy, including swallowed audio-session, recording, recognizer and online fallback errors. Underlying wrapped errors retain their details. Transcript logging is private; HTTP response bodies are excluded because they can contain transcripts. Model errors, unavailable-model fallback and keyword fill use category `planner`.
  4. Debug/messages: Explicit microphone/speech permission, missing microphone/audio engine and recognizer-unavailable cases have the required plain messages; unknown failures have a plain retry/type message. DEBUG messages append domain/code (the underlying error for wrapped failures). Persistent input failures return to idle instead of restarting capture automatically.
  5. Debug/typing: `Type instead` has the keyboard symbol and a minimum 44 x 44 pt target; it stops capture/output and presents a labelled text field and Send button. It remains available after permission/input failures. Typed and spoken transcripts both enter `receive` then `handle`; switching input mode preserves the pending slot and retry count, and typed follow-ups do not restart the microphone.
  6. First sentence/keyword: Handles from/to and to/from ordering, need-to-get-to, wanna-go-from-to, take-me-to and get-me-to; trims punctuation and repeated trailing filler.
  7. First sentence/model: Instructions explicitly request both stated places. Every resilient model intent extraction also runs keyword extraction, filling nil/whitespace origin, destination or mode without replacing existing model values. Fill changes the answer source to `onDeviceModelWithKeywordFill`.
  8. First sentence/tests: Both requested test files use the same seven cases, including all three required sentences, and compare trimmed, case-insensitive place names. Foundation Models tests use the resilient wrapper and throw `XCTSkip` when unavailable. Deterministic stub-model tests separately cover partial fill, whitespace, preservation and thrown errors for all four brain methods.
  9. Follow-up/extraction: Added `extractPlace(from:for:)`; the model generates one optional `place` field, while keywords remove the specified leading phrases/hesitations and trailing filler. Only the extracted, trimmed place can fill an intent slot.
  10. Follow-up/retry: A nil/empty answer asks `Sorry, which station or suburb?` once for the same slot. A second failure clears the trip and pending question and says `Let's start again. Where would you like to go?`. Cancellation resets the retry count. Engine tests cover both slots, reset and typed question preservation.
  11. Follow-up/tests: Keyword tests include Central, Town Hall, Holsworthy and nil for `um`, plus repeated filler, alternate prefixes and empty input, for both slots.
  12. Facts/closing caption: Uses the task's practice-complete wording and explains selecting a trip and following its steps in the real app.
  13. Facts/results: Three clearly labelled example trip options with `Times show here in the real app`; removed departure/arrival times, durations, platforms and the misleading Next label. Transport naming and brand color definitions are unchanged.
  14. Facts/prompts: Shared model conversation instructions forbid times, platforms, routes, lines, frequencies and prices for both clarification and confirmation. Keyword conversation wording is preserved.
  15. Facts/search: The exact required pattern over `NearMe/` returns no matches.
- Verify commands run and results:
  - `git branch --show-current`: `task/P02a-debug-parsing-facts`; initial working tree was clean.
  - `git diff --check`: passed, exit 0.
  - `git grep -n -i -E '[0-9]{1,2}:[0-9]{2} ?(am|pm)|platform [0-9]|leaves shortly' -- NearMe/`: no matches, expected exit 1.
  - `git grep -n 'filling(.*transcript\|Something went wrong with the microphone' -- NearMe/`: no matches, expected exit 1.
  - Python static inspection: required adaptation header preserved in all 16 modified Swift files; counted 16 new test methods. New standalone test files are original task code.
  - `git diff --name-only -- docs/SPEC.md docs/PLAN.md CLAUDE.md AGENTS.md project.yml`: no changes. Reviewed the diff for scope, new force unwraps and privacy annotations; no new force unwraps or build-setting changes.
  - `Get-Command swift,xcodebuild,python -ErrorAction SilentlyContinue`: only Python is present. This Windows machine has no Swift or Xcode. The requested Mac verify commands and XCTest suite were NOT run; no build or runtime pass is claimed. `rg` was unavailable, so searches used git grep and PowerShell.
- Mac test steps for the owner:
  1. After the manager has committed/transferred this work, check out `task/P02a-debug-parsing-facts`. From the repository root run `bash scripts/mac-run.sh test --current`. Expect 20 test methods total; the real Foundation Models method skips if the model is unavailable. Inspect planner logs to distinguish a real model answer from generation-time fallback; deterministic stub tests verify keyword-fill behavior regardless of availability.
  2. Run `bash scripts/mac-run.sh --current`. Grant microphone access to DeviceHub in macOS if required, then grant NearMe microphone and speech permissions in the simulator. In separate sessions try `I wanna go from Central to Holsworthy`, `to Parramatta from Town Hall`, and `I need to get to Town Hall`. The first two should go directly to confirmation; the third should ask for origin. Repeat with Type instead and Send.
  3. Speak `I need to get to Holsworthy`, then tap Type instead while the origin question is pending. Send `I'm leaving from Central`; confirm only Central is used. In another typed session send `to Holsworthy`, then `um`, then `uh`: expect the single retry followed by a cleared trip and the restart prompt. Send a new trip to confirm no old slot is retained. Also try `travel from Central` followed by `to Holsworthy please` for the destination slot.
  4. In another terminal run `xcrun simctl spawn booted log stream --style compact --level debug --predicate 'subsystem == "au.nearme.ios" AND (category == "voice" OR category == "planner")'`. Deny NearMe microphone permission, then separately deny speech recognition permission in simulator Settings > Privacy & Security and retry a session. Check the specific Settings guidance, DEBUG domain/code, public error metadata and usable Type instead path. Where hardware allows, disconnect the active input device and check the microphone-unavailable message. Check an unavailable recognizer/audio-engine case if reproducible; `VoiceDiagnosticsTests` covers their message mappings deterministically. With an existing configured ElevenLabs key, an offline request should log its error and fall back without exposing a response body or transcript.
  5. Complete a guided practice. Verify the source badge on every session screen, labelled example results with no fabricated facts, and the exact practice-complete caption. Test the voice and typed screens with the keyboard open, VoiceOver, light/dark appearance and Accessibility XXXL text; ensure the badge, caption and primary controls do not overlap and Send/Type instead remain reachable by scrolling.
  6. Run `xcodebuild -scheme NearMe -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build`. If NearMe is running, terminate it with `xcrun simctl terminate booted au.nearme.ios`. Run `xcrun simctl install booted build/Build/Products/Release-iphonesimulator/NearMe.app` then `xcrun simctl launch booted au.nearme.ios`. Confirm the badge and domain/code suffixes are absent in Release, while typing and plain error messages remain available.
- Not done / risks / questions: Mac compilation, all XCTest execution, real-model output, audio hardware/permissions, visual layout and accessibility checks remain the owner's gate. Keyword place extraction is deliberately a phrase/filler heuristic, not a place database; it cannot disambiguate a garbled place name. Model factual restrictions are prompt instructions, not a live-data validator. Existing screen-guidance claims and other baseline UI behavior outside P02a remain for later tasks. No merge, push, CI run or subsequent task was started.
- Commit: pending the normal current-branch commit attempt; if the sandbox blocks `.git`, the manager must commit the working tree.

## Review (round 1)
- Date: 2026-10-24 14:51 AEDT
- Verdict: CHANGES (static review; no compiler here, CI off by owner decision, Mac compile is the gate)
- No definite compile errors found: imports, changed signatures, all four TaskPlannerBrain conformers, Logger privacy syntax and #if DEBUG placement checked. Keyword cases traced by hand: all pass. Facts grep: clean.

Fixes (address every one):
1. TaskPlannerBrain.swift:64-83: keyword fill never upgrades the intent kind. When the model returns kind unknown and the keyword parse returns plan_journey with a place, set the intent to plan_journey as well (source onDeviceModelWithKeywordFill). Otherwise the engine still rejects "I wanna go from Central to Holsworthy" and the model test fails.
2. VoiceSessionView.swift:24 and TaskPlannerEngine: after Type instead the user can never return to voice (orb tap is gated on isTyping, and cancel does not reset it). Remove the gate so tapping the orb returns to voice (userTappedToTalk already clears isTyping), add a visible "Use voice" button (SF Symbol mic, 44 x 44 pt) next to the text field, and reset isTyping in cancelCurrentAction and endSession.
3. FoundationModelsBrain.swift:55 / ResilientTaskPlannerBrain.extractPlace: the model may return the whole answer as the place. Pass the model's place through the keyword place extractor before using it; if the model returns nil, use the keyword extractor's result before re-asking.
4. VoiceSessionView.swift:45: use a single-line TextField (no axis: .vertical) with .submitLabel(.send) so the keyboard Send key submits.
5. TaskPlannerEngine.swift:186: do not leave the no-speech message (with its DEBUG suffix) on screen while listening again; clear lastErrorMessage when listening restarts.
6. SessionContainerView.swift:50: use .background(.background) (SwiftUI) instead of the UIKit .systemBackground member, or add import UIKit.
7. Add or update unit tests for fixes 1 and 3 (model unknown plus keyword plan_journey becomes plan_journey; "I'm leaving from Central" returned whole by a stub model becomes Central).

## Dev Report (round 2)
- Date: 2026-10-24 14:52 AEDT
- Changed files: `NearMe/Services/Intelligence/TaskPlannerBrain.swift`; `NearMe/ViewModels/TaskPlannerEngine.swift`; `NearMe/Views/Voice/VoiceSessionView.swift`, `SessionContainerView.swift`; `NearMeTests/ResilientTaskPlannerBrainTests.swift`, `TaskPlannerEngineTests.swift`; this task report. The log entry follows the commit attempt.
- What I did: Addressed every numbered fix in Review (round 1), keeping changes within P02a. Added five deterministic test methods (25 total now) and adjusted existing engine tests for the typing reset.
- Acceptance criteria / review fixes (implemented; Mac execution pending):
  1. Unknown model intents now become `plan_journey` when keyword parsing finds a journey with a place. This sets `onDeviceModelWithKeywordFill`, including when the kind is the only correction; existing model slot values remain preserved.
  2. The idle orb accepts taps in typing mode. A visible `Use voice` button with the `mic` symbol and minimum 44 x 44 pt target sits beside the single-line field, stacking at accessibility text sizes. Both controls dismiss keyboard focus and call `userTappedToTalk`, preserving the pending question. The button is disabled during processing/speech. Cancel and end session reset `isTyping`; existing engine tests assert both resets, and the cancel test explicitly re-enters typing before submitting a new trip.
  3. The resilient brain cleans every non-nil model place through the keyword place extractor. If the model place is nil or cleans to nothing, it extracts from the original answer before returning nil. Keyword changes report `onDeviceModelWithKeywordFill`; unchanged model answers retain their source, and thrown model errors still report keyword fallback. This applies to Foundation Models through its existing factory wrapper without duplicating cleanup in the model class.
  4. Removed the vertical TextField axis; `.submitLabel(.send)` and `.onSubmit(sendTypedAnswer)` now use a single-line field and the same submission handler as the visible Send button.
  5. `listenAndHandle` clears `lastErrorMessage` immediately before entering `.listening`, including automatic retries after no speech. This clears the DEBUG suffix along with the old message.
  6. The DEBUG badge uses SwiftUI `.background(.background)` with no UIKit dependency.
  7. New stub tests cover unknown-to-journey promotion with empty and already-filled model slots; no promotion without a keyword place; a whole model answer cleaned to Central; nil/blank/filler model places filled from the original answer for either slot; and preservation of an already-clean model place/source. Existing tests retain nil when neither extractor finds a place and cover thrown-model fallback.
  - Original criteria: debug visibility and source reporting remain intact; first-sentence parsing now also repairs intent kind; follow-up parsing now cleans model output and fills model omissions; fact-free captions/results/prompts are unchanged and the facts search remains clean. These are implementation/static findings, not a runtime acceptance pass.
- Verify commands run and results:
  - `git branch --show-current`: `task/P02a-debug-parsing-facts`; initial working tree clean.
  - `git diff --check`: passed, exit 0.
  - `git grep -n -i -E '[0-9]{1,2}:[0-9]{2} ?(am|pm)|platform [0-9]|leaves shortly' -- NearMe/`: no matches, expected exit 1.
  - `rg -n 'func test' NearMeTests`: 25 test methods, five added this round. Tests were inspected, not executed.
  - `git diff --name-only -- docs/SPEC.md docs/PLAN.md CLAUDE.md AGENTS.md project.yml`: no changes. Diff review found no new force unwraps, build-setting changes or secret additions; adaptation headers remain in the four changed app Swift files.
  - `Get-Command swift,xcodebuild,rg,python -ErrorAction SilentlyContinue`: Swift and Xcode unavailable; rg and Python present. This Windows machine has no Swift or Xcode. Neither Mac verify command nor XCTest was run, and no compile/runtime success is claimed.
- Mac test steps for the owner:
  1. After these changes are committed/transferred, run `git checkout task/P02a-debug-parsing-facts` from the repository root, then `bash scripts/mac-run.sh test --current`. Expect 25 test methods, including the five new resilient-brain regressions. The real Foundation Models test may skip when unavailable; deterministic stub tests must run.
  2. Run `bash scripts/mac-run.sh --current`. Grant DeviceHub microphone access in macOS and NearMe microphone/speech permissions in the simulator. Tap Type instead, enter `I need to get to Holsworthy`, and press the keyboard Send key. Verify it submits and asks for origin. Tap Use voice, say `I'm leaving from Central`, and verify the journey uses Central. Repeat in a new session, using the orb instead of Use voice to return from typing to speech.
  3. In separate typed sessions submit `I wanna go from Central to Holsworthy` and `to Parramatta from Town Hall`; expect confirmation without another place question. Submit `to Holsworthy`, then `um`, then `uh`; expect one retry followed by the restart prompt and a cleared trip. The stub tests exercise unknown model intent and whole/nil model place output deterministically.
  4. Enter typing mode and tap cancel. Verify the field disappears and the orb starts voice again. Complete a journey in typing mode, end the session, and start another session; verify it starts in voice mode.
  5. While listening, remain silent until the no-speech retry occurs. Verify the error and DEBUG domain/code disappear as listening restarts. Check Use voice, Send and cancel with the keyboard open, VoiceOver, light/dark appearance and Accessibility XXXL; the field/button should stack at accessibility sizes and controls remain reachable. Check the source badge through voice and guided practice screens.
  6. Run `xcodebuild -scheme NearMe -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build`. Verify Release compiles with the DEBUG badge excluded. Repeat the fact search: `git grep -n -i -E '[0-9]{1,2}:[0-9]{2} ?(am|pm)|platform [0-9]|leaves shortly' -- NearMe/` (expect no matches, exit 1).
- Not done / risks / questions: Mac compilation, XCTest, model availability, actual microphone retry timing and visual/accessibility validation remain the owner's gate. Keyword cleanup remains a phrase/filler heuristic and cannot validate whether a place exists. No merge, push, CI run or subsequent task was started.
- Commit: pending current-branch commit attempt; if `.git` is blocked, the manager must commit the working tree.
