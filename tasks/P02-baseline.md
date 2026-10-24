# P02: Baseline test on the Mac (simulator, and iPhone if available)

| Field | Value |
|---|---|
| Status | todo |
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
5. Voice: speak "I need to get to Melbourne Central" (simulator uses the Mac microphone). Note whether the transcript appears and which engine ran (no Secrets.xcconfig means on-device Apple speech)
6. Typed or alternative input, if the app offers one
7. Planner: does it ask a sensible follow-up (for example where you are leaving from) and confirm the trip
8. Guided walkthrough: step through to the end; captions, spoken output, progress, and the final screen
9. End or cancel the session; return to onboarding
10. With a real ElevenLabs key in Secrets.xcconfig: voice input again
11. iPhone (if available): `bash scripts/mac-run.sh device`, then checks 2 to 9 on the phone; note Foundation Models availability (Apple Intelligence on) and whether opening the real transport app works
12. Anything that crashes, hangs, looks wrong at large text sizes, or says something misleading

## Report
`bash scripts/mac-run.sh report`, or paste the list to the manager.
