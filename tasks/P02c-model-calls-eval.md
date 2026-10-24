# P02c: Bounded model calls, latency, model eval out of the default tests

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct, now, before P02b |
| Depends on | P02a |
| Assignee | codex |
| Branch | task/P02c-model-calls-eval |

## Goal
On the Mac, `FoundationModelsBrainTests.testTripSentencesThroughResilientBrain` ran over 9 minutes; at about 7 minutes the model threw "The session's transcript exceeded the model's context size" and the brain fell back to keywords. Every session is already created per call, so the cause is a runaway response inside one call. Make every model call short and bounded, measure it, and keep slow real-model tests out of the default run.

## Read
AGENTS.md. Files: `NearMe/Services/Intelligence/FoundationModelsBrain.swift`, `TaskPlannerBrain.swift` (BrainAnswer, BrainSource, ResilientTaskPlannerBrain, PlannerDiagnostics), `KeywordFallbackBrain.swift`, `NearMe/Models/JourneyIntent.swift` (@Generable JourneyIntent), `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Views/Voice/SessionContainerView.swift` (Debug badge), `NearMeTests/`, `scripts/mac-run.sh`.

## Acceptance criteria
### 1. One fresh, bounded session per call
- [ ] Every model call (extract intent, clarifying question, confirmation, place cleanup) creates a new `LanguageModelSession` inside the call. No stored, static, cached or shared session anywhere (`git grep -n "LanguageModelSession"` shows only local `let session = LanguageModelSession(` lines inside those four functions, plus the availability check)
- [ ] Instructions are short (each under 60 words) and no longer ask for text "exactly as they said it" in a way that invites long output. The @Guide descriptions for place fields say a short place name of at most 5 words
- [ ] Every `respond` passes `GenerationOptions(sampling: .greedy, maximumResponseTokens: N)`: intent extraction 120, place cleanup 40, clarifying question 60, confirmation 60
- [ ] Every model call has a timeout of 10 s (one constant). On timeout or any error the call throws, the resilient brain falls back to keywords as today, and the planner log says which call timed out or failed

### 2. Latency
- [ ] Each model call's wall-clock latency in ms is measured with `ContinuousClock` and logged with `Logger` category "planner": call kind, outcome (ok, timeout, error), ms. No transcripts or place names at `.public`
- [ ] `BrainAnswer` carries the latency of the call that produced it (nil for keyword-only answers); `TaskPlannerEngine` publishes it; the Debug badge shows it, for example "On-device model, 840 ms" or "Keyword fallback" (Debug builds only, as today)

### 3. Real-model tests out of the default run
- [ ] Default `NearMeTests` never construct `FoundationModelsBrain` or call the brain factory: they use a fake brain (stub `TaskPlannerBrain` conformer with canned answers). Keyword brain tests stay as they are
- [ ] The real-model tests move to `NearMeTests/ModelEvalTests.swift`, class `ModelEvalTests`. Every test there calls `XCTSkip` unless the environment variable `NEARME_MODEL_EVAL` is `1`, and also skips when the model is unavailable
- [ ] At most 3 sentences: "I wanna go from Central to Holsworthy", "to Parramatta from Town Hall", "I need to get to Town Hall". Each runs through the resilient brain with a 20 s per-sentence timeout and fails (not hangs) if exceeded
- [ ] For each sentence the test prints one line to stdout: `EVAL | <sentence> | origin=<x> destination=<y> kind=<k> | <brain source> | <ms> ms`

### 4. `eval` mode in scripts/mac-run.sh
- [ ] `bash scripts/mac-run.sh eval [--current]`: same pull and xcodegen as other modes, newest simulator, then `xcodebuild test ... -only-testing:NearMeTests/ModelEvalTests` with `TEST_RUNNER_NEARME_MODEL_EVAL=1` in the environment (xcodebuild passes `TEST_RUNNER_`-prefixed variables to the test process without the prefix). Prints every `EVAL |` line and the test result line, full log in `build/xcodebuild.log`. Usage line and README table updated
- [ ] Default `test` mode does not set the variable, so the eval is skipped there

## Verify (Mac)
```
bash scripts/mac-run.sh test --current   # fast; ModelEvalTests skipped
bash scripts/mac-run.sh eval --current   # 3 EVAL lines, each under 20 s
```

<!-- Dev Reports and Reviews appended below. -->
