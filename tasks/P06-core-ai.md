# P06: The on-device model does more (Core AI)

| Field | Value |
|---|---|
| Status | todo (after P05 and its Mac check) |
| Window | Sat 24 Oct |
| Depends on | P05 |
| Assignee | codex |
| Branch | task/P06-core-ai |

## Goal
Foundation Models routes requests, answers "what do I do now?", helps after wrong taps and explains elements, always grounded in the current practice screen. Privacy is stated plainly and is true in code.

## Read
AGENTS.md; docs/SPEC.md section 4; docs/design/HIG-NOTES.md rules 1, 9, 10, 12. Files: `NearMe/Services/Intelligence/` (BrainAnswer, BrainSource, ResilientTaskPlannerBrain, PlannerCallDeadline, PlannerDiagnostics), `NearMe/ViewModels/TaskPlannerEngine.swift`, `TripPlannerPracticeViewModel.swift`, `NearMe/Models/PracticeStep.swift`, `NearMe/Views/TripPlannerPractice/`, P05's Settings sheet, `NearMeTests/`, `scripts/mac-run.sh` (eval mode).

## Shared rules for every new model call
New `LanguageModelSession` per call, greedy sampling, `maximumResponseTokens` 60 (router 40), 10 s deadline via `PlannerCallDeadline`, latency logged and shown in the Debug badge, keyword or scripted fallback on any error. Prompts contain only what is listed for that call, never transcripts from earlier turns.

## Acceptance criteria
### 1. Task router
- [ ] After the user's first sentence, a `@Generable` router picks from `enum PracticeTask { tripPlanner, notAvailableYet }` (defined so new tasks are added in one place). Keyword fallback: trip words (go, get to, travel, train, bus, from, to) give tripPlanner, otherwise notAvailableYet
- [ ] notAvailableYet: NearMe says kindly what it can help practise today (for example "I can't practise that one yet. Today I can help you practise planning a trip, like getting to Town Hall."), then listens again. tripPlanner continues into today's trip flow unchanged

### 2. "What do I do now?"
- [ ] A Help button (SF Symbol `questionmark.circle` plus "Help", 44 x 44 pt) on practice screens, and the phrases "help", "what do I do", "what do I do now" (spoken or typed) during practice
- [ ] Each practice screen exposes a `ScreenContext`: screen name, the current step's target label, the step instruction, and the visible element labels (defined from the same label constants as the views). The model receives only that context
- [ ] Answer: at most 2 short plain sentences, element labels in double quotes. Validator (pure, tested): every quoted label must exactly match (case-insensitive) a visible label; at most 2 sentences and 200 characters; otherwise the scripted step instruction is used instead. The answer is shown in the caption bar and spoken

### 3. Wrong-tap help
- [ ] Taps on non-target elements are counted per step (reset when the step advances). 1st wrong tap: "Not quite. Look for \"<target>\"." 3rd wrong tap: model-generated simpler explanation of where the target is (same context, same validator), and the target pulses. With Reduce Motion on, the target gets a static thicker outline instead of a pulse

### 4. Tap and hold to explain
- [ ] Long-press on any element of a practice screen: the model explains what it does in one sentence, grounded in that element's label and the screen name (validator: at most 1 sentence, any quoted label must be visible; fallback: "This is \"<label>\"."). Long-press never triggers the element's tap action. Elements expose the hint to VoiceOver ("Touch and hold to hear what this does")

### 5. Privacy
- [ ] "What stays on your phone" screen opened from Settings, with this copy (owner-approved): "To speak in a natural voice, NearMe sends the sentence it is about to say to ElevenLabs. That can include place names you mentioned. Everything else (understanding you, guidance, help) stays on your phone, and nothing is saved." Plus one line: "Turn off Natural voice (online) in Settings and nothing leaves your phone." When Natural voice is off, the screen says instead: "Natural voice is off, so nothing leaves your phone. Understanding you, guidance and help all run on your phone, and nothing is saved."
- [ ] True in code: no transcript, typed text, place name or model answer is written to disk, UserDefaults or the voice cache key in readable form (the cache file name is a hash; cached audio contains only NearMe's own lines). The conversation history is cleared when a session ends or is cancelled. All Logger interpolation of user or model text uses `privacy: .private`; Release builds never log user text at any level

### 6. Tests
- [ ] Default run (fake brain, no model): router mapping and keyword fallback, help validator accept and reject cases, wrong-tap counter (1st nudge, 3rd escalation, reset on advance), long-press fallback, conversation cleared on end
- [ ] Real-model cases in `ModelEvalTests` (NEARME_MODEL_EVAL=1, `eval` mode), at most 4 more, each with a 20 s limit and an `EVAL |` line: "help me order groceries" gives notAvailableYet; "I need to get to Town Hall" gives tripPlanner; one help answer and one long-press answer pass the validator

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh eval --current
bash scripts/mac-run.sh quick
```
Mac checks: "help me order groceries" gives a polite not-available-yet answer; during practice "what do I do now" gives a correct grounded answer; 3 wrong taps give simpler help and a pulse; long-press explains an element; the Debug badge shows On-device model and ms for each.

<!-- Dev Reports and Reviews appended below. -->
