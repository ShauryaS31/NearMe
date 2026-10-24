# P07d: Router fix, a strong guide match beats a model "general" pick

| Field | Value |
|---|---|
| Status | in_progress |
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
