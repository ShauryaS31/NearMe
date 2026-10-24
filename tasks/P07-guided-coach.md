# P07: Help with any app: guided coach

| Field | Value |
|---|---|
| Status | in_progress |
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

## Dev Report (round 1)
- Date: 2026-10-24 17:23 AEDT
- Changed files:
  - New: `NearMe/Models/Guide.swift`, `NearMe/Models/CoachSession.swift`, `NearMe/Services/Intelligence/GuideLibrary.swift`, `NearMe/Services/Intelligence/HelpRouter.swift`, `NearMe/Services/Intelligence/CoachModelService.swift`, `NearMe/Views/Voice/CoachView.swift`, `NearMeTests/GuidedCoachTests.swift`.
  - Updated integration: `NearMe/App/AppCoordinator.swift`, `NearMe/App/ContentView.swift`, `NearMe/App/NearMeApp.swift`, `NearMe/Info.plist`, `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Views/Voice/SessionContainerView.swift`, `project.yml`.
  - Qualified the existing Foundation Models `@Guide` attributes to avoid a name collision with the new Codable `Guide`: `NearMe/Models/JourneyIntent.swift`, `NearMe/Services/Intelligence/FoundationModelsBrain.swift`.
  - Guide metadata only: `check_ios_update.json`, `connect_wifi.json`, `facetime_contact.json`, `send_text_message.json`, `set_alarm.json`, `share_photo_from_photos.json`, `turn_on_do_not_disturb.json`, `turn_on_torch.json`, `whatsapp_send_photo.json`, `whatsapp_video_call.json`, `whatsapp_voice_message.json`, all under `NearMe/Resources/guides/`.
  - Updated tests/tooling/docs: `NearMeTests/ModelEvalTests.swift`, `NearMeTests/OnDeviceVoiceInputTests.swift`, `NearMeTests/TaskPlannerEngineTests.swift`, `NearMeTests/VoiceEngineIntegrationTests.swift`, `NearMeTests/VoiceReviewTests.swift`, `scripts/mac-run.sh`, `scripts/validate-guides.py`, `docs/design/GUIDES.md`, this task file.
- What I did:
  - Added a bundled, validated guide library; pure candidate ranking with optional sentence vectors; exclusive help routing; and a separate guide/general coach using P04 speech input/output.
  - Added request/person normalisation, safe nearby-label wording, next-step rewrite preparation, session commands, public app launch buttons, in-memory switching recovery, and anonymous guide progress restoration.
  - Added the help home with its large mic action, exact example hint, typed request and secondary practice card. Reserved space for P05 Settings. Finishing/stopping guidance returns home instead of onboarding.
  - Journey extraction is guarded by the trip route. Removed the infinitive in a routed request such as "want to practise" before journey extraction so the old keyword extractor does not treat the practice request as a destination. Exhausted journey clarification resets routing for the next request.
  - Kept Swift 5 mode and MainActor default isolation. Dependency and test defaults are optional arguments constructed inside their bodies; no new force unwraps. Existing journey/voice tests explicitly inject a fake practice router and unavailable coach model.
- Acceptance criteria (implementation evidence; Swift/runtime acceptance still requires the Mac gate):
  - 1, library: all 15 JSON files are explicitly bundled as a `guides` folder. Codable models and the Swift loader check the same schema, file set, duplicate/unknown keys, canonical format, labels, aliases, content heuristics, source metadata and scheme restrictions as the Python validator. Debug launch asserts validation; a default hosted test loads the same bundled resources. Debug coach steps show "Check on your screen" for `verify: true`. Original guide instructions, aliases and source notes were preserved.
  - 2, router: NaturalLanguage sentence embeddings cover title plus aliases, combined with pure keyword scoring; nil vectors use keyword-only scoring. Only three candidates enter the fresh generable router session. Unknown or noncandidate ids become general. One fallback threshold selects a guide before checking trip words, then general.
  - 2b, exclusivity: the engine routes the first request before journey extraction; guide/general cases return into coaching. Guide commands bypass journey extraction too. Tests cover all seven exact phrases through the prefilter, fake model router, keyword fallback and engine route boundary; an additional spoken-request/command test checks that a photo request never calls the journey brain. The opt-in eval includes all seven phrases with route, source and elapsed milliseconds.
  - 2c, person: optional generable person output and keyword extraction pass through the placeholder check and normalise Mum/Dad/your son/your daughter/names. Fallback photo/chat steps use "Open your chat with Mum."; rewrite prompts receive the session person, and person-bearing rewrites must retain it. Requests and people are held only in session memory and cleared on finish/stop; persisted restoration has no person or request.
  - 2d, nearby labels: schema and Python validator accept only a real optional boolean. Set the four required flags and nine more nearby landmarks/status/recipient cases after reviewing every guide. Fallback says `Look near "<label>"`; rewrite validation rejects tapping that label case-insensitively, including "tap on", and requires the nearby wording. Content-preservation checks confirmed only this metadata changed in the JSON files.
  - 3, coach: one `.title` instruction, matching speech and step count; quote/length/sentence validation; next-step rewrite preparation; Done/Next, Repeat, persistent Slower, I'm stuck and Stop via buttons, typing and speech. SF Symbols accompany controls with at least 44 pt targets. Completion says "That's it, you're done." and returns home. Stale routing/rewriting results cannot restart a cancelled session.
  - 4, general: fresh generation is capped at six steps and 200 tokens, with one-action/cautious/no-invented-specifics instructions. Validation checks step/sentence bounds and rejects certainty words and obvious compound actions. Every displayed general step has the required visible label and shared commands; stuck explanations use a fresh bounded call. Invalid/unavailable results use the exact specified fallback.
  - 5, switching/opening: only the existing documented `whatsapp://` and `sms:` schemes can produce launch buttons, checked by `canOpenURL` and listed in Info.plist. No private Settings URL is used. Scene backgrounding stops capture/playback while retaining the session; activation speaks the required welcome-back line. Only guide id and index enter UserDefaults, with validation on restoration and clearing on stop/finish/general guidance.
  - 6, home: after onboarding the home shows "What do you need help with?", the exact Mum/WhatsApp hint, typed input, and a secondary Practice mode card routed through the same router. Settings space is reserved for P05.
  - 7, tests: added 17 default fake/content tests for validation, ranking, all seven routes, person handling, nearby/rewrite/general validation, commands, speech integration, progress privacy, restoration, switching, pending-call cancellation and rewrite preparation. Added nine real-model eval cases (seven routes, one Mum rewrite, one stuck response), each with an outer 20-second limit and `EVAL |` output. Real rewrite evals must report the model source, so fallback text cannot masquerade as a successful generation. Existing three journey evals remain.
  - Shared model rules: every router/rewrite/stuck/general call creates a new tool-free session, uses greedy sampling and 40/80/80/200 response-token limits, and runs behind `PlannerCallDeadline` with a 10-second deadline. Latency/outcome are logged and returned for the Debug badge. Errors and invalid results take deterministic fallbacks. Router prompts contain only the request and candidate ids/titles/aliases; rewriting sees only the request, current step/label/nearby flag and session person; general sees the request, and general stuck sees its current step.
- Verify commands run and results:
  - `python scripts/validate-guides.py`: passed, `Validated 15 guides: 0 problems.`
  - Python standard-library checks via `python -`: validator syntax parses; all guide content is unchanged after removing newly added nearby flags; the nearby flag rejects string/number/null/list/object values and accepts true/false; Info.plist parses and lists exactly the two used public query schemes. Passed.
  - PyYAML inspection via `python -`: project file parses, the explicit guides resource folder is present, and Swift 5/MainActor build settings remain unchanged. Passed.
  - Tree-sitter Swift syntax inspection via `python -`: all 19 changed/new Swift files parsed. The existing conditional SwiftUI modifier chain was checked separately with Debug enabled and disabled because the parser cannot parse that conditional chain directly. This is syntax inspection only, not compilation, macro expansion or type checking.
  - `git diff --check`: passed; Git only emitted existing CRLF-to-LF conversion notices.
  - `git branch --show-current`: `task/P07-guided-coach`.
  - `Get-Command swift,xcodebuild,xcodegen -ErrorAction SilentlyContinue`: no installed commands. This Windows machine has no Swift or Xcode. No Swift build, XCTest run, real-model eval or iPhone/UI test was run or claimed to pass.
- Mac test steps for the owner:
  1. Use the manager-published `task/P07-guided-coach` checkout. From the repository root run `python3 scripts/validate-guides.py`; expect 15 guides and zero problems.
  2. Run `bash scripts/mac-run.sh test --current`. Require the complete hosted test suite, including `GuidedCoachTests`, to pass. This regenerates the project and includes the new resources/sources. Do not commit `NearMe.xcodeproj`.
  3. On a supported Apple Intelligence host/runtime with the model available, run `bash scripts/mac-run.sh eval --current`. Inspect `build/xcodebuild.log` for seven P07 route lines plus a Mum rewrite and a stuck line, all below 20 seconds and using the on-device model. Also retain the three existing journey lines. A skipped eval is not a model pass.
  4. Run `bash scripts/mac-run.sh quick`. Complete onboarding and verify the large help mic, exact example hint, typed request, practice card and reserved Settings space. Exercise light/dark appearance, largest Dynamic Type, Bold Text and VoiceOver; check wrapping, control labels and the always-reachable Stop action.
  5. With signing configured and the iPhone connected, run `bash scripts/mac-run.sh device --current`. Speak each exact phrase from 2b in a fresh session: "can you help me send an image to my mom", "send pictures to my son on whatsapp", "photo bhejna hai whatsapp pe", "the text is too small I can't read", "video call my daughter", "I want to practise planning a train trip", and "how do I change my ringtone". Expect photo/photo/photo/text-bigger/video-call/practice/general respectively. Only practice may ask journey questions. Repeat the seven by typing and with Apple Intelligence unavailable to check the keyword fallback.
  6. For the mom photo request, advance to step 3. Expect Mum and "Look near \"Chats\"", never an instruction to tap Chats on that step. Check Done/Next, Repeat, Slower followed by Repeat/Next, I'm stuck, typed commands, spoken commands and Stop. Complete a guide and hear "That's it, you're done." before returning home. Review every existing `verify: true` step against the actual iPhone/app layout.
  7. With WhatsApp installed, verify Open WhatsApp appears and opens it. Return to NearMe and hear the welcome-back line at the same step with Mum retained. Repeat switching with general guidance and check its visible warning on every step. Verify Settings guides offer the guide instruction without any private Settings launch button.
  8. On guide step 3, terminate and relaunch NearMe, then reach home after onboarding. Expect the same guide/index with the anonymous person wording and a welcome-back line. Stop, relaunch again and verify nothing restores. General guidance must survive switching but must not restore after process termination.
  9. While a router or rewrite is preparing, cancel/Stop; wait at least 10 seconds and verify no late answer starts guidance. Check the Debug model source/latency badge and repeat speech controls using both configured ElevenLabs output and system fallback.
- Not done / risks / questions:
  - The owner's Mac is the build/test gate. Swift 6.4 actor/type checking, Foundation Models macro/API compatibility, real-model routing quality, resource copying, actual public app launches and accessible rendering remain unverified on this machine.
  - The 36 existing guide verification flags remain unconfirmed on a physical device. Nearby metadata records orientation semantics; it does not certify app UI accuracy.
  - General guidance is intentionally labelled as potentially different from the user's screen. The app does not observe or control another app.
  - No changes to SPEC.md, PLAN.md, CLAUDE.md or AGENTS.md; no secrets or generated Xcode project added. No other task was started.
  - Git staging succeeded on the current branch. Intended commit: `N07: Add exclusive help routing and guided coaching`.
  - Commit blocked: `git commit -m "N07: Add exclusive help routing and guided coaching"` exited 1 with `fatal: Unable to create 'C:/Users/User/Desktop/projects/NearMe/.git/index.lock': Permission denied`. All changes are uncommitted; implementation files are staged, and this final report update is unstaged. The manager must stage the updated report and commit. No permission escalation or alternate Git directory was attempted.
  - Per the user's explicit sandbox-failure instruction, stopped after recording the failed commit. The post-commit `docs/LOG.md` line has not been appended; after committing, the manager can append: `- 2026-10-24 17:23 AEDT | N07 | codex | dev-report r1 | Exclusive help routing and guided coaching including 2b/2c/2d; Mac gate pending (committed by manager)`.
