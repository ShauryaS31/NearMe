# P07: Help with any app: guided coach

| Field | Value |
|---|---|
| Status | todo (top priority: dispatch right after P04b, before P05) |
| Window | Sat 24 Oct |
| Depends on | P04b, P07a |
| Assignee | codex |
| Branch | task/P07-guided-coach |

## Goal
NearMe helps with any phone task, not one scripted flow: it recognises what the user wants, coaches them one step at a time for known tasks from a curated guide library, and gives clearly labelled general guidance for everything else. The trip planner practice stays as a secondary practice mode.

## Read
AGENTS.md; docs/SPEC.md section 4; docs/design/HIG-NOTES.md rules 1, 2, 6, 7, 10, 11, 13, 14. Files: `NearMe/Services/Intelligence/` (BrainAnswer, BrainSource, ResilientTaskPlannerBrain, PlannerCallDeadline, PlannerDiagnostics), `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Views/Voice/`, `NearMe/App/`, `NearMe/Info.plist`, `project.yml`, P04's voice output, `NearMeTests/`, `scripts/mac-run.sh` (eval mode).

## Shared rules for every model call
New `LanguageModelSession` per call, greedy sampling, `maximumResponseTokens` (router 40, step rewrite 80, stuck 80, general 200), 10 s deadline via `PlannerCallDeadline`, latency logged and shown in the Debug badge, deterministic fallback on any error (fallbacks listed per item). Prompts contain only what the item lists.

## Acceptance criteria
### 1. Guide library
- [ ] The 15 guide files already exist from P07a (`NearMe/Resources/guides/<id>.json`, schema in docs/design/GUIDES.md). Bundle them as resources (add to project.yml); do not rewrite their content except to fix validator problems. Guides: WhatsApp send a photo, WhatsApp video call, WhatsApp voice message, iPhone make text bigger, connect to Wi-Fi, take a screenshot, share a photo from Photos, FaceTime a contact, add a contact, turn on Do Not Disturb, check for iOS updates, set an alarm, call from Recents, turn on the torch, send a text message
- [ ] Schema as in docs/design/GUIDES.md: `id`, `title`, `app`, optional `app_url_scheme`, `aliases`, `steps` [{`instruction`, `ui_label_hint`, optional `verify`}], `source_note`, `last_checked`. A `Guide` Codable model and a loader that validates every file at launch in Debug (assert) and in a unit test (same rules as scripts/validate-guides.py). Steps with `verify: true` show a small "Check on your screen" note in Debug builds only
- [ ] Steps: one action each, written for iOS 26/27 and current WhatsApp, using the exact on-screen label in `ui_label_hint` (for example "Settings", "Accessibility", "Display & Text Size", "Larger Text"). No guessing beyond what you are confident of; where an app differs between versions, say so in `source_note`. Plain words, no jargon

### 2. Router
- [ ] Prefilter: rank guides against the request with `NLEmbedding.sentenceEmbedding(for: .english)` cosine similarity over title plus aliases, combined with a keyword alias score; keep the top 3 (pure, tested; keyword-only if the embedding is unavailable)
- [ ] `@Generable` choice: `practiceTripPlanner`, `guide` (one of the 3 candidate ids, enforced: any other id becomes `general`), or `general`. The model sees only the request and the 3 candidates' ids, titles and aliases
- [ ] Fallback: top prefilter candidate if its score passes a threshold (one constant), else trip words give practice, else general
- [ ] This router replaces P06 item 1 (P06 will build on it)

### 2b. Routing is exclusive (owner, from the phone: "can you help me send an image to my mom" went into the trip flow)
- [ ] The trip practice flow (origin and destination questions, journey extraction, practice screens) starts ONLY when the router returns `practiceTripPlanner`. Every other route goes to the coach or general guidance and never asks for an origin or destination. The engine's first-sentence handling calls the router first; journey extraction runs only inside the trip practice route
- [ ] Router acceptance phrases (exact), each with an expected route:
  - "can you help me send an image to my mom": `whatsapp_send_photo`
  - "send pictures to my son on whatsapp": `whatsapp_send_photo`
  - "photo bhejna hai whatsapp pe": `whatsapp_send_photo`
  - "the text is too small I can't read": `iphone_text_bigger`
  - "video call my daughter": `whatsapp_video_call`
  - "I want to practise planning a train trip": `practiceTripPlanner`
  - "how do I change my ringtone": `general`
- [ ] Unit tests (default run): the prefilter puts the expected guide in its top 3 for each guide phrase, and the router with a fake brain that returns the expected choice routes exactly as listed; the keyword fallback (model unavailable) also routes all 7 correctly (add aliases or keywords such as "image", "picture", "pictures", "mom", "mum" only to the router's keyword scoring, not to the guide files' meaning)
- [ ] Eval (`NEARME_MODEL_EVAL=1`): all 7 phrases through the real router, one `EVAL |` line each with the route and ms, 20 s limit each

### 2c. Personalise the person
- [ ] The router's `@Generable` output also has an optional `person` (who the user mentions: "mom", "Mum", "my son", "my daughter"). Normalise for speech: mom, mum, mummy, mother become "Mum"; dad, daddy, father become "Dad"; "my son" becomes "your son", "my daughter" becomes "your daughter", other names as said, capitalised. Keyword fallback extracts the same set. Run it through the P03a `PlaceNormalization`-style placeholder check ("nil", "none" and so on mean no person)
- [ ] Coach steps use it: step text that refers to "the person" (for example "Tap the chat with the person you want to send the photo to.") is personalised, deterministically in the fallback text ("Open your chat with Mum.") and as an instruction to the model rewrite. If no person is mentioned, keep "the person". The person is never stored beyond the session

### 2d. Nearby labels
- [ ] Add an optional per-step field `label_is_nearby: true` to the guide schema (docs/design/GUIDES.md and scripts/validate-guides.py) and set it on steps whose `ui_label_hint` is only a nearby label, not the thing to tap: `connect_wifi` step 4 ("Wi-Fi") and step 3 of `whatsapp_send_photo`, `whatsapp_video_call` and `whatsapp_voice_message` ("Chats"); check the other guides for the same pattern
- [ ] For those steps the coach says "Look near \"<label>\"" and never "Tap \"<label>\"": the fallback text is built that way, and the rewrite validator rejects any rewrite containing "tap \"<label>\"" (case-insensitive) for a nearby-label step

### 3. Coach session
- [ ] One step at a time: the step shown in large text (`.title` style) and spoken (P04 voice). Progress "Step 2 of 5"
- [ ] The model rewrites the guide step in plain words for the user's request: at most 2 sentences, UI labels in double quotes exactly as in the step's `ui_label_hint`. Validator (pure, tested): every quoted label must equal a `ui_label_hint` of this guide's steps; at most 2 sentences, 200 characters; otherwise the guide's own `instruction` is used. Rewrites for the next step are prepared while the current one is shown
- [ ] Commands by voice or typing, and as buttons (SF Symbol plus text, 44 x 44 pt): "Done" / "Next" (also "done", "next", "ok", "got it"), "Repeat", "Slower" (system-voice rate down or ElevenLabs line re-spoken slower; persists for the session), "I'm stuck" (the model gives an alternative explanation grounded in the same step; same validator; fallback: the instruction plus "Look for \"<ui_label_hint>\"."), "Stop" (ends the coach, back home)
- [ ] Finish: "That's it, you're done." then back home

### 4. General guidance
- [ ] For `general`, the model writes at most 6 short steps (one action each) shown and spoken one at a time with the same commands. A visible label on every step: "General guidance: your screen may look different". Instructions forbid certainty words and invented specifics; validator: at most 6 steps, each at most 2 sentences; on failure: "I'm not sure about that one. Try asking a family member, or ask me another way."

### 5. Open the app, survive switching
- [ ] "Open <app>" button only where the guide has a documented public URL scheme (for example `whatsapp://`, `facetime://` only with a contact, `sms:`, `tel:`), listed in `LSApplicationQueriesSchemes` in Info.plist and checked with `canOpenURL`. No `App-prefs:` or other private Settings URLs: Settings guides say "Open the Settings app" instead. `UIApplication.openSettingsURLString` only for NearMe's own settings
- [ ] Coach state (guide id, step index, general steps) survives app switching: kept in memory, restored on `scenePhase` active with "Welcome back. You were on step 3: ..." spoken. Only the guide id and step index may be written to UserDefaults (for relaunch), never the user's words; cleared when the coach finishes or stops

### 6. Home screen
- [ ] After onboarding, home shows a big primary "What do you need help with?" mic button (also typable), with the hint text under the mic: "Try: 'Help me send a photo to Mum on WhatsApp'", and a secondary "Practice mode" card that opens today's trip planner practice. Gear for Settings stays where P05 puts it (if P05 is not done yet, leave space)

### 7. Tests
- [ ] Default run (fakes): every guide file loads and validates (15, unique ids, non-empty steps and hints); prefilter ranks "how do I send a photo on WhatsApp" to the WhatsApp photo guide and "make the writing bigger" to make text bigger; router fallback; rewrite validator accept and reject; general validator; commands parsing; coach state restore
- [ ] Eval (`NEARME_MODEL_EVAL=1`, 20 s each, `EVAL |` lines): the 7 router phrases from 2b, plus one rewrite (with person "Mum") and one stuck answer that pass the validator

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh eval --current
bash scripts/mac-run.sh quick
```
Mac/iPhone checks: all 7 phrases from 2b, spoken on the phone, route correctly (none of the guide phrases asks where you are starting from); "can you help me send an image to my mom" coaches with "Mum" in the steps; "how do I send a photo on WhatsApp" gives the WhatsApp guide, steps one by one, Done/Repeat/I'm stuck work; "how do I change my ringtone" gives general guidance with the label; the Open WhatsApp button is present (on a phone with WhatsApp); leaving the app and coming back resumes the step. Owner: check the `verify: true` steps from P07a on the iPhone.

<!-- Dev Reports and Reviews appended below. -->
