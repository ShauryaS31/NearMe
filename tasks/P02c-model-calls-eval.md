# P02c: Bounded model calls, latency, model eval out of the default tests

| Field | Value |
|---|---|
| Status | done (Mac compile pending) |
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


## Dev Report (round 1)
- Date: 2026-10-24 15:17 AEDT
- Changed files: `NearMe/Services/Intelligence/FoundationModelsBrain.swift`, `TaskPlannerBrain.swift`, new `PlannerCallDeadline.swift`; `NearMe/Models/JourneyIntent.swift`; `NearMe/ViewModels/TaskPlannerEngine.swift`; `NearMe/Views/Voice/SessionContainerView.swift`; removed `NearMeTests/FoundationModelsBrainTests.swift`, new `ModelEvalTests.swift` and `PlannerCallDeadlineTests.swift`, updated `ResilientTaskPlannerBrainTests.swift` and `TaskPlannerEngineTests.swift`; `scripts/mac-run.sh`; `README.md`; this task file.
- What I did: Added bounded, measured generation and a cancellation-aware deadline helper. The helper cancels losing work and stops awaiting it at the deadline, so slow cancellation acknowledgement cannot delay keyword fallback. Added deterministic deadline, error, cancellation, fallback, and latency regression coverage. Moved real-model evaluation into its own opt-in class and added the Mac eval command.
- Acceptance criteria:
  - 1, fresh sessions: all four functions create a local session inside their per-call operation; no session is stored or shared. `git grep -n LanguageModelSession -- '*.swift'` shows exactly four local constructors.
  - 1, short instructions: extraction is 51 words, conversation 43, place cleanup 32. Removed the verbatim-place instruction; origin, destination, and cleanup guides specify a short name of at most 5 words.
  - 1, generation limits: all four respond calls explicitly use greedy sampling and maximum response tokens of 120 (intent), 40 (place), 60 (question), and 60 (confirmation).
  - 1, timeout/fallback: one production constant is 10 seconds. Every call uses the deadline helper and rethrows timeout/errors; the resilient brain retains keyword fallback for all four operations. Diagnostics identify the call kind and timeout/error outcome.
  - 2, latency/logging: ContinuousClock measures elapsed milliseconds; the planner Logger emits call kind, ok/timeout/error, and milliseconds. Error descriptions and domains are private; model-call log messages contain no transcript or place values.
  - 2, answer/UI: BrainAnswer carries optional latency, preserved through keyword supplementation; keyword-only answers default to nil. The engine publishes latency after each of its four call sites. The Debug-only badge and accessibility label include milliseconds when present and show Keyword fallback without milliseconds otherwise.
  - 3, default suite: only ModelEvalTests references or constructs FoundationModelsBrain; it checks the environment before model availability/construction. No test invokes the factory. Engine tests now use canned fake answers, resilient tests retain a stub primary, and keyword tests are unchanged.
  - 3, opt-in eval: the sole ModelEvalTests test throws XCTSkip unless NEARME_MODEL_EVAL is 1 and the model is available. It evaluates exactly the three specified sentences through the resilient brain, with a 20-second deadline per sentence and explicit assertion failure on errors/timeouts. Each sentence prints one EVAL line with places, kind, source and total sentence milliseconds (including fallback time); failure lines identify that no answer was produced.
  - 4, script/docs: eval shares pull/XcodeGen/newest-simulator preparation, exports TEST_RUNNER_NEARME_MODEL_EVAL=1 only for its build invocation, and selects only ModelEvalTests. Default test does not set the variable. All EVAL lines and test result lines are displayed on success or failure; full output remains in build/xcodebuild.log. Usage and the README table include eval.
- Verify commands run and results:
  - `git diff --check`: passed (Git emitted only the existing Windows LF/CRLF normalization notice for README).
  - `bash -n scripts/mac-run.sh`: passed using Git Bash.
  - `git grep -n LanguageModelSession -- '*.swift'`: four local constructors only. Python static assertions passed for instruction lengths, token limits, timeout use and absence of real-model/factory references outside ModelEvalTests.
  - Temporary Python/Git Bash mock harness exercised the actual shell script with stand-ins for Mac tools: eval --current success, test --current success, eval with checkout/pull, and eval failure all passed. Verified flag forwarding, test selection, simulator destination, XcodeGen, all three mock EVAL lines, result lines and full-log retention. This was a shell test, not an Xcode/model test. Initial harness attempts hit Windows WSL/python3 aliases; rerunning with explicit Git Bash and Python paths passed. Temporary harness files were removed.
  - Swift and Xcode are not installed on this machine. Neither Mac verify command nor any Swift unit test, compile, real-model timing check or UI check was run. The owner's Mac is the gate; no CI was triggered.
- Mac test steps for the owner:
  1. After the manager makes the branch available, check out `task/P02c-model-calls-eval` on the Mac. From the repository root run `unset NEARME_MODEL_EVAL TEST_RUNNER_NEARME_MODEL_EVAL`, then `bash scripts/mac-run.sh test --current`. Require a passing test run, including PlannerCallDeadlineTests and the fake-brain regressions, with ModelEvalTests skipped.
  2. Run `bash scripts/mac-run.sh eval --current`. With Foundation Models available, require exactly three EVAL lines, correct places/kind, each elapsed value below 20000 ms, and TEST SUCCEEDED. Inspect the reported brain source: fallback is permitted and is not evidence of model quality. If the model is unavailable the eval must skip; rerun on the owner's available-model simulator to complete this gate.
  3. Inspect `build/xcodebuild.log` for the full eval output. Run `bash scripts/mac-run.sh test --current` again and confirm eval is skipped, proving the opt-in environment did not leak between invocations.
  4. Run `bash scripts/mac-run.sh sim --current`. In a second Terminal run `xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "au.nearme.ios" AND category == "planner"'`. In the app use Type instead: submit `I need to get to Town Hall`, then `from Central`. Confirm intent extraction, clarifying question, place cleanup, and confirmation each log call/outcome/ms and the Debug badge shows the latest successful model latency or Keyword fallback. Confirm no input/place values are public in planner logs.
  5. On any observed slow/error model response, confirm timeout/error is logged with the call kind and that the planner continues via keywords after about 10 seconds instead of waiting for the generation to finish. The default deadline regression test separately covers a fake operation that ignores cancellation, so a naturally slow model is not required for deterministic coverage.
  6. In Xcode select the NearMe scheme, Edit Scheme > Run > Info > Build Configuration > Release; run on the simulator and confirm the source/latency badge is absent. Restore Debug afterward.
- Not done / risks / questions: Swift API/macro/concurrency compatibility, XCTest execution, actual model latency, and UI behavior remain unverified until the Mac gate. Cancellation is cooperative: an underlying framework generation may keep running after the caller has timed out, but its late result is discarded and cannot update the planner. The deadline assumes the executor remains responsive; it cannot preempt synchronous framework code that blocks the main actor. The shell mock also exposed an existing behavior: a failing python3 simulator-selector subprocess can leave an empty destination because command-substitution error handling continues; no change was made outside this task's scope. No protected project documents, build settings, secrets, or generated Xcode project were changed.

## Review (round 1)
- Date: 2026-10-24 15:18 AEDT
- Verdict: PASS (static). Mac compile and `eval` run pending (owner).
- Sessions: four local `let session = LanguageModelSession(` lines, one per call, nothing stored. Greedy sampling and token caps 120/40/60/60; shorter instructions and 5-word place guides. PlannerCallDeadline returns at 10 s even if generation ignores cancellation (late result discarded), covered by a fake-operation test. Latency logged per call (kind, outcome, ms; values private) and shown in the Debug badge. Default tests use stubs; only ModelEvalTests builds the real brain, skipped unless NEARME_MODEL_EVAL=1, 3 sentences, 20 s each, EVAL lines printed. `eval` mode passes TEST_RUNNER_NEARME_MODEL_EVAL=1 with -only-testing.
- Follow-up moved to P02b: a failing simulator selector inside $(...) does not stop the script (errexit is not inherited by command substitution).
