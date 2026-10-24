# P07d: Router fix, a strong guide match beats a model "general" pick

| Field | Value |
|---|---|
| Status | todo (waiting for the owner's exact phrase and debug line) |
| Window | Sat 24 Oct |
| Depends on | P07b |
| Assignee | codex (worktree, parallel to P11) |
| Branch | task/P07d-router-override |

## Goal
On the iPhone, a "send an image to Mum" style request was answered with the general fallback "I'm not sure about that one" instead of the WhatsApp photo guide. A request that clearly matches a guide must never end in general guidance just because the model picked "general".

## Evidence (owner, from the iPhone)
- Phrase: `<EXACT PHRASE FROM OWNER>`
- Debug line: `<DEBUG BADGE LINE FROM OWNER>`
- Note: "I'm not sure about that one" is the general-guidance failure message, so the router chose general AND general guidance then failed or was rejected.

## Read
AGENTS.md. Files: `NearMe/Services/Intelligence/HelpRouter.swift` (GuidePrefilter.rank, fallback, fallbackThreshold, HelpRouter.route), `NearMe/Services/Intelligence/CoachModelService.swift`, `NearMe/Services/Intelligence/PlannerModelAccess.swift`, `NearMeTests/GuidedCoachTests.swift` (router acceptance tests), `NearMeTests/ModelEvalTests.swift`.

Swift 6.4 rules: default arguments must not construct NearMe or test types or read MainActor statics; split long chains over tuples into typed steps.

## Acceptance criteria
- [ ] Override rule in `HelpRouter.route`: if the model returns `general` (or a guide id outside the shortlist, today's "rejected" case) and the prefilter's top candidate has a keyword-weighted score at or above `GuidePrefilter.fallbackThreshold`, route to that guide instead. The model still decides between two guide candidates and still routes to practice; the override only replaces a `general` (or rejected) pick. Source shown and logged as "On-device model + keyword fill" with reason "general overridden by guide match" (category "planner", top candidate id and score public, no user text)
- [ ] The owner's exact phrase from Evidence is added to the router acceptance phrases: unit test with a fake brain that returns `general` (must route to `whatsapp_send_photo` via the override), unit test with the keyword fallback alone (must route to `whatsapp_send_photo`), and an eval case (`NEARME_MODEL_EVAL=1`). If the keyword score for the phrase is below the threshold, add the missing words (for example "image", "pic", "picture", "send", "mum", "mom") to the router's keyword scoring for that guide, not to the guide file's meaning
- [ ] The 7 existing acceptance phrases still pass, including "how do I change my ringtone" staying `general` (its keyword score must stay below the threshold) and "I want to practise planning a train trip" staying practice
- [ ] If the debug line shows general guidance itself failed (validator rejected or model error), log the reason under "planner" ("general rejected: <rule>") so the next failure is diagnosable; do not change the general validator rules in this task

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh eval --current
```
iPhone check: the owner's exact phrase coaches the WhatsApp photo guide with "Mum"; the badge says "On-device model" or "On-device model + keyword fill"; "how do I change my ringtone" still gives labelled general guidance.

<!-- Dev Reports and Reviews appended below. -->
