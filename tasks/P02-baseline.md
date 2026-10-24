# P02: Baseline test on the Mac (simulator, and iPhone if available)

| Field | Value |
|---|---|
| Status | done |
| Window | Sat 24 Oct, after P01 |
| Depends on | P01 |
| Assignee | owner on Mac, manager writes up |
| Branch | - (results go to docs/mac-results/) |

## Goal
List exactly what works and what breaks in the imported app before planning P03 onwards. No code changes in this task.

## Checks (record WORKS or BROKEN, plus what you saw, for each)
1. `bash scripts/mac-run.sh test`: NearMeTests result (expect 4 JourneyIntent tests)
2. `bash scripts/mac-run.sh`: builds, simulator boots, NearMe launches; home screen name and icon say NearMe
3. Onboarding: Welcome, greeting, screen-guidance explainer; both choices on the explainer
4. Permission prompts: microphone and speech recognition text says NearMe
5. Voice (simulator: grant macOS microphone permission to DeviceHub first): speak "I need to get to Melbourne Central" (simulator uses the Mac microphone). Note whether the transcript appears and which engine ran (no Secrets.xcconfig means on-device Apple speech)
6. Typed or alternative input, if the app offers one
7. Planner: does it ask a sensible follow-up (for example where you are leaving from) and confirm the trip
8. Guided walkthrough: step through to the end; captions, spoken output, progress, and the final screen
9. End or cancel the session; return to onboarding
10. With a real ElevenLabs key in Secrets.xcconfig: voice input again
11. iPhone (if available): `bash scripts/mac-run.sh device`, then checks 2 to 9 on the phone; note Foundation Models availability (Apple Intelligence on) and whether opening the real transport app works
12. Anything that crashes, hangs, looks wrong at large text sizes, or says something misleading

## Report
`bash scripts/mac-run.sh report`, or paste the list to the manager.

## Results (2026-10-24 14:41 AEDT, owner, manual Mac run, simulator, iOS 27)
- WORKS: full flow end to end (onboarding, voice, follow-up, confirmation, guided practice to the end).
- WORKS after setup: microphone, once macOS microphone permission is granted to DeviceHub.
- NEEDS: debug visibility of which brain answered (on-device model or keyword fallback); real voice errors are hidden behind a generic microphone message; no way to type instead of speaking. P02a item 1.
- BUG: "I wanna go from Central to Holsworthy" was not parsed as origin and destination; the app asked "Where are you heading from Central?". P02a item 2.
- BUG: follow-up answers are written raw into the trip ("Bhool Swati Holsworthy"). P02a item 3.
- BUG: invented facts, for example the closing line "first service leaves shortly from Platform 2"; the results screen also shows made-up times and platforms. P02a item 4.
- DECISION: the practice screens imitate a real Melbourne transport brand; rebrand to a generic Trip planner with Sydney places. P03.
