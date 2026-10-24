# P07d: Router fix, a strong guide match beats a model "general" pick

| Field | Value |
|---|---|
| Status | done (combined iPhone check after P11) |
| Window | Sat 24 Oct |
| Depends on | P07b |
| Assignee | codex (worktree ../NearMe-p07d, parallel to P11 and the P09 lane) |
| Branch | task/P07d-router-override |

## Goal
On the iPhone, a "send an image to Mum" style request was answered with the general fallback "I'm not sure about that one" instead of the WhatsApp photo guide. A request that clearly matches a guide must never end in general guidance just because the model picked "general".

## Evidence (owner, from the iPhone)
- 18:28: a "send an image to Mum" style request gave "I'm not sure about that one" (general guidance failed) while Apple Intelligence was still downloading.
- After the download: "can you help me send an image to my mom" routed to `whatsapp_send_photo`, badge "Understood: On-device model, 2132 ms | Voice: ElevenLabs, first audio 2.68 s | STT 103 ms".
- So routing works with the model; the override below is a safety net. Use the 7 standard acceptance phrases from P07 item 2b plus "can you help me send an image to my mom".

## Read
AGENTS.md. Files: `NearMe/Services/Intelligence/HelpRouter.swift` (GuidePrefilter.rank, fallback, fallbackThreshold, HelpRouter.route), `NearMe/Services/Intelligence/CoachModelService.swift`, `NearMe/Services/Intelligence/PlannerModelAccess.swift`, `NearMeTests/GuidedCoachTests.swift` (router acceptance tests), `NearMeTests/ModelEvalTests.swift`.

Swift 6.4 rules: default arguments must not construct NearMe or test types or read MainActor statics; split long chains over tuples into typed steps.

## Acceptance criteria
- [ ] Override rule in `HelpRouter.route`: if the model returns `general` (or a guide id outside the shortlist, today's "rejected" case) and the prefilter's top candidate has a keyword-weighted score at or above `GuidePrefilter.fallbackThreshold`, route to that guide instead. The model still decides between two guide candidates and still routes to practice; the override only replaces a `general` (or rejected) pick. Source shown and logged as "On-device model + keyword fill" with reason "general overridden by guide match" (category "planner", top candidate id and score public, no user text)
- [ ] "can you help me send an image to my mom" is (or stays) in the router acceptance phrases: unit test with a fake brain that returns `general` (must route to `whatsapp_send_photo` via the override), unit test with the keyword fallback alone (must route to `whatsapp_send_photo`), and an eval case (`NEARME_MODEL_EVAL=1`). If the keyword score for the phrase is below the threshold, add the missing words (for example "image", "pic", "picture", "send", "mum", "mom") to the router's keyword scoring for that guide, not to the guide file's meaning
- [ ] The 7 existing acceptance phrases still pass, including "how do I change my ringtone" staying `general` (its keyword score must stay below the threshold) and "I want to practise planning a train trip" staying practice
- [ ] If the debug line shows general guidance itself failed (validator rejected or model error), log the reason under "planner" ("general rejected: <rule>") so the next failure is diagnosable; do not change the general validator rules in this task

### Owner bugs from the same iPhone run (same task)
- [ ] 1. Personalisation lost: the coach steps said "the person" although the user said "my mom". Trace where the person is dropped (router choice, keyword extraction, coach session creation, auto-open path, rewrite, resume) and fix it so every step that refers to "the person" says "Mum" (rewrite and fallback). Test: the request "can you help me send an image to my mom" through the router with a fake brain and with keyword fallback gives person "Mum" and step 3 text containing "Mum"
- [ ] 2. Nearby-label wording: never "Look near "<label>" and tap it" and never "look near X, then tap it". For a step with `label_is_nearby`, describe the real target and place it by the label, for example "In your "Chats" list, tap Mum's name." (person applied; without a person: "In your "Chats" list, tap the person's name."). Never "tap "<label>"" for those steps. For a normal step (for example "+", "Photos"), say plainly "Tap "+"." Apply to the fallback text and the rewrite validator (reject "look near" and reject "tap "<nearby label>""); update the tests that expect "Look near"
- [ ] 3. Auto-open did not happen: confirm `LSApplicationQueriesSchemes` contains `whatsapp` (and `sms`), log under "planner" (or "coach") the auto-open decision: guide id, url, canOpenURL result, opened result, or the reason it was skipped (not first step, no scheme, not installed). If WhatsApp is not installed (canOpenURL false), say "WhatsApp isn't on this phone." and keep step 1 as a normal instruction; never stay silent
- [ ] 4. Instant acknowledgement: as soon as speech ends (and for typed input when it is sent), speak a short template line "Sure, let me help you with that." while the router and model run (system voice is fine if ElevenLabs audio for it is not cached; cache it). Do not say it for follow-up answers (places, Done, Repeat, commands) or when the turn is a command. It counts as first audio in the badge. The guide's first step follows when ready, without overlapping speech
- [ ] 5. Step icons (data only; the coach card display comes in the P09 review): add an optional `icon` field (SF Symbol name) to guide steps in docs/design/GUIDES.md, scripts/validate-guides.py (must be a non-empty string if present), the `HelpGuide.Step` model and every step of the 15 guides where a clear symbol exists (for example "plus" for "+", "photo.on.rectangle" for Photos, "bubble.left" for chats, "video" for video call, "textformat.size" for text size, "gearshape" for Settings, "paperplane" for send, "mic" for microphone, "flashlight.on.fill" for torch). Use only SF Symbols that exist in iOS 26; the validator keeps passing

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh eval --current
```
iPhone check: "can you help me send an image to my mom": "Sure, let me help you with that." is spoken right after you stop talking, then the WhatsApp photo guide with "Mum" in the steps, WhatsApp opens by itself (or "WhatsApp isn't on this phone."), step 3 says "In your \"Chats\" list, tap Mum's name."; the badge says "On-device model" or "On-device model + keyword fill"; "how do I change my ringtone" still gives labelled general guidance.

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)
- Date: 2026-10-24 18:49 AEDT
- Changed files:
  - `NearMe/Services/Intelligence/HelpRouter.swift`, `CoachModelService.swift`, `GuideLibrary.swift`; `NearMe/Models/HelpGuide.swift`; `NearMe/ViewModels/TaskPlannerEngine.swift`.
  - `NearMe/Services/Speech/VoiceOutputService.swift`, `ElevenLabsVoiceOutput.swift`.
  - All 15 JSON files under `NearMe/Resources/guides/` (76 step icons only); `scripts/validate-guides.py`; `docs/design/GUIDES.md`.
  - `NearMeTests/GuidedCoachTests.swift`, `ModelEvalTests.swift`, `ModelAvailabilityTests.swift`, `CoachAppOpenTests.swift`, `ElevenLabsVoiceOutputTests.swift`, `VoiceReviewTests.swift`; new `NearMeTests/HelpAcknowledgementTests.swift`; this task file.
- What I did:
  - Added the strong-match override after the model answers. General and out-of-shortlist choices become the top guide at or above 0.56, with the existing combined keyword/embedding score. Valid shortlisted guide choices and practice choices are preserved. Unavailability, errors and timeouts retain ordinary keyword fallback reporting.
  - Traced person handling across routing, keyword extraction, session creation, auto-open, rewrite/prefetch, app switching and restored progress. Explicit request extraction now takes priority over a model person. Session creation also recovers the request person if a router omits it, and rewriting recovers a missing person and rejects anonymous text when personalisation is required. In-memory resume already preserved the person. Full process relaunch deliberately remains anonymous: only guide id/index are persisted, as required by P07's privacy contract.
  - Replaced nearby fallback orientation with actual target wording, including exactly `In your "Chats" list, tap Mum's name.` (or `the person's name`). Other nearby steps keep their target/action and orient it by their existing label. Updated the rewrite prompt and validator to reject `look near` and tapping a nearby label. Normal target steps retain direct tap instructions.
  - Added public auto-open diagnostics for guide id, safe allowlisted URL, canOpenURL, opened result and skip reasons. Missing apps speak `<App> isn't on this phone.` and retain normal step 1. Confirmed the existing Info.plist already lists both `whatsapp` and `sms`; no plist edit was needed.
  - Added acknowledgement at speech-end callback and typed send, concurrent with routing. It uses cached ElevenLabs audio or immediate system speech while prefetching the template. Guide/announcement speech waits for completion. Stopped capture can deliver its final decoded result during acknowledgement, and cancellation prevents late guide speech. Commands, coach follow-ups and practice/place answers are excluded. Playback callbacks record the acknowledgement as first audio; typed turns now have a send-time baseline too.
  - Added optional icon decoding and matching Swift/Python schema validation, plus 76 icon names. Guide instructions, aliases and source notes are unchanged. No coach-card display changes were made (P09 owns display).
- Acceptance criteria (implementation and test coverage; Swift runtime acceptance awaits the owner's Mac):
  1. Override: `HelpRouter.route` applies only to successful model general/out-of-shortlist picks with a strong top match. Source is `On-device model + keyword fill`; planner log reason is `general overridden by guide match`, with public candidate id/score and no request text. Tests cover general, rejected, weak ringtone, alternative shortlisted guide and practice choices.
  2. Mom phrase: already present among P07's seven exact phrases, so it remains in both shared acceptance tests and opt-in eval. Added fake-general and keyword-only routing-to-step-3 tests asserting `whatsapp_send_photo`, `Mum`, and personalised fallback/stuck/rewrite text. Existing scoring gives the phrase 0.9 without embeddings (at least 0.72 with the existing 80/20 weighting), so no keyword or guide-meaning changes were necessary.
  3. Seven phrases: preserved all exact cases and their expected routes. Fake-model and unavailable-model tests remain; new override tests exercise all five guide phrases. Ringtone explicitly asserts a score below threshold. Practice is preserved even when the request also has a strong guide match. Real-model eval accepts either model or model-plus-keyword-fill, never a pure fallback as a model pass.
  4. General failure diagnosis: factored the existing validator predicates into named rejection reasons without changing their acceptance rules. Logs emit `general rejected: <rule>` for validator failures, and the shared failure reason for model errors/timeouts/unavailability. Added rule-name assertions; existing general validation cases remain.
  5. Owner bug 1: request-derived person survives router override/fallback, coach creation, auto-open and live resume. Tests cover wrong/model-omitted person, valid and anonymous rewrites, step 3 after auto-open/resume and anonymous full relaunch.
  6. Owner bug 2: exact Chats wording is asserted for Mum and anonymous use; tests reject both forbidden look-near forms and direct taps on the nearby label. Added validation of every nearby fallback with and without Mum.
  7. Owner bug 3: schemes verified; diagnostics and audible missing-app explanation added. Existing opening, failure rollback, interruption and resume tests updated, including the exact missing-WhatsApp line and preservation of step 1.
  8. Owner bug 4: dedicated tests cover speech-end acknowledgement before final transcript, typed acknowledgement concurrent with a suspended router, no overlap, first-audio playback events, cancellation, command/follow-up suppression, and uncached-system then cached-ElevenLabs playback. Existing voice tests account for the extra initial line.
  9. Owner bug 5: optional non-empty icon schema documented and implemented; all 15 guides carry clear symbols. Hosted test loads every name with `UIImage(systemName:)` on the target OS and checks absent/invalid icon values. The Python validator passes. Symbol availability remains part of the Mac/iOS gate; Apple's availability guidance: https://developer.apple.com/documentation/uikit/configuring-and-displaying-symbol-images-in-your-ui .
- Verify commands run and results:
  - `python scripts/validate-guides.py`: PASS, `Validated 15 guides: 0 problems.`
  - Python standard-library checks via `python -`: PASS, 15 guides / 76 icons; removing only icons exactly reproduces HEAD's guide content; icon absence is accepted and null/bool/number/list/object/empty/whitespace/padded values are rejected; Info.plist parses and contains WhatsApp/SMS query schemes; validator syntax parses.
  - `git diff --check`: PASS (only existing line-ending conversion warnings).
  - `Get-Command swift,xcodebuild -ErrorAction SilentlyContinue`: neither tool is installed. This Windows machine has no Swift or Xcode. No Swift build, hosted tests, model eval or iPhone checks were run or claimed to pass.
  - Read-only branch/status check: current branch is `task/P07d-router-override`; worktree was initially clean. `rg` is unavailable, so searches used PowerShell.
- Mac test steps for the owner:
  1. In the Mac checkout containing this task's committed changes, verify `git branch --show-current` and `git status --short`; use this branch (or the manager's reviewed integration). Run `python3 scripts/validate-guides.py` from the repository root.
  2. Run `bash scripts/mac-run.sh test --current`. Require the entire hosted suite to pass, including GuidedCoachTests, ModelAvailabilityTests, HelpAcknowledgementTests, CoachAppOpenTests, ElevenLabsVoiceOutputTests and VoiceReviewTests. This also checks every bundled icon on iOS. Do not commit NearMe.xcodeproj.
  3. With Apple Intelligence ready on a supported runtime, run `bash scripts/mac-run.sh eval --current` (sets NEARME_MODEL_EVAL=1). Require seven help-route EVAL lines, Mum rewrite and stuck cases, and the existing journey cases to pass below their deadlines. A skip is not a model pass. Inspect `build/xcodebuild.log` on failure.
  4. With signing configured and an iPhone connected, run `bash scripts/mac-run.sh device --current`. In fresh spoken and typed sessions test: `can you help me send an image to my mom`; `send pictures to my son on whatsapp`; `photo bhejna hai whatsapp pe`; `the text is too small I can't read`; `video call my daughter`; `I want to practise planning a train trip`; `how do I change my ringtone`. Expect photo/photo/photo/text-size/video-call/practice/general respectively. Repeat with model unavailable to exercise keyword fallback.
  5. For the mom phrase, verify acknowledgement immediately after speech ends or typed send, then nonoverlapping guide speech. With WhatsApp installed it opens only after its opening announcement; return and advance to step 3, expecting `In your "Chats" list, tap Mum's name.` Repeat, Slower and I'm stuck retain Mum. Done/Repeat and practice place replies must not repeat the acknowledgement. Test Stop during acknowledgement/router work; no late guide should appear.
  6. On a device/simulator without WhatsApp, repeat the mom phrase: hear `WhatsApp isn't on this phone.` then normal step 1, without advancing or silently dropping the instruction. Test Messages launch as well. Inspect category `planner` in Console for auto-open URL/canOpenURL/opened/skip entries and override reason/id/score. For an actual general model failure, confirm `general rejected: <rule/reason>` without user/generated text in the public log.
  7. Inspect the Debug badge: model or model-plus-keyword-fill for the routed request; acknowledgement playback supplies first-audio timing. Repeat once with an empty speech cache and once warm; uncached acknowledgement uses system speech immediately, cached audio may use ElevenLabs. Confirm ringtone still displays labelled general guidance. Background/resume retains Mum; full termination/relaunch intentionally restores anonymous progress.
- Not done / risks / questions:
  - Swift 6.4 compilation, real model behaviour, physical app launching, audible timing and symbol existence on the target iOS runtime remain unverified until the Mac gate. Existing guide verify flags remain for owner device review.
  - No SwiftUI body/display changes, build-setting changes, new force unwraps, default-argument type constructions, secrets or generated Xcode project. SPEC.md, PLAN.md, CLAUDE.md and AGENTS.md are untouched. Other task worktrees were not modified.
  - Commit intended: `P07d: Override general routing and fix coach handoff feedback`. Post-commit LOG entry is appended only if Git succeeds, following the requested order.

## Review (round 1)
- Date: 2026-10-24 18:51 AEDT
- Verdict: PASS (static). Merged to main first (owner merge order); combined iPhone check after P11.
- Override only for on-device answers that pick general or an off-shortlist guide while the top candidate meets the threshold; logged "general overridden by guide match" with candidate and score. Person from the request wins over the model's; Chats steps say "In your \"Chats\" list, tap Mum's name."; other nearby steps "By \"<label>\", ..."; validator rejects "look near" and "tap <nearby label>". Auto-open logs every decision and says "<app> isn't on this phone." when not installed. Instant acknowledgement only for new requests (not commands, follow-ups, coach or practice), first step waits for it, cached. General rejection reasons logged by rule name only. 29 distinct step icons, all real SF Symbols; validator 0 problems. New protocol method has a default; default-argument scan clean (the one hit reads a nonisolated constant).
