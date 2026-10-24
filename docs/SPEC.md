# NearMe: Spec (iPhone)

Version 2.0, Saturday 24 October 2026. Owner: Shaurya V Sharma. Pivoted to iPhone; the earlier macOS plan (version 1.0) is parked on branch `archive/mac-nearme`.
Full background, rubric and prior-art notes: `docs/MASTER-PLAN.md`. Rubric: `docs/RUBRIC.md`.

## 1. What NearMe is

A voice-first iPhone companion that helps older, non-technical people get everyday phone tasks done, one spoken step at a time. It starts from a prior prototype (adapted, used with permission) and improves it.

## 2. Baseline (what P01 imported)

Behaviour is exactly the prior prototype's, with only renaming and build setup changed. To be confirmed on the Mac in P02.

| Area | Baseline | Files |
|---|---|---|
| Onboarding | Welcome, greeting, screen-guidance explainer with two choices | `NearMe/Views/Onboarding/` |
| Voice in | ElevenLabs speech to text when a key is set, otherwise on-device Apple speech | `NearMe/Services/Speech/` |
| Understanding | Foundation Models on device when available, keyword fallback otherwise; asks one follow-up question, then confirms | `NearMe/Services/Intelligence/`, `NearMe/ViewModels/TaskPlannerEngine.swift` |
| Guidance | Simulated public transport journey walkthrough with captions and spoken steps | `NearMe/Views/PTVSim/`, `NearMe/ViewModels/PTVSimulationViewModel.swift` |
| Voice out | Spoken instructions | `NearMe/Services/Speech/VoiceOutputService.swift` |
| App launch | Opens the real transport app by universal link or URL scheme | `NearMe/Services/AppLauncher/` |
| Screen guidance | In-app ReplayKit and Vision service; broadcast extension source kept but not a target | `NearMe/Services/ScreenGuidance/`, `Shared/`, `NearMeBroadcastExtension/` |
| Tests | 4 journey intent tests | `NearMeTests/` |

## 3. Platform facts

- A third-party iPhone app cannot read, highlight or tap inside other apps. A screen broadcast gives pixels only, while the app is in the background, with no overlay.
- Foundation Models needs Apple Intelligence on a supported device (or a supported Mac host for the simulator); the keyword fallback covers the rest.
- Minimum iOS 26.5.

## 4. Rules

- Guide, do not take over: NearMe never acts in other apps for the user.
- Works offline with on-device speech and the keyword fallback. Online services (ElevenLabs) only with a key, and they must fall back silently.
- No secrets in git: keys come from `Secrets.xcconfig` through Info.plist.
- Every file adapted from the prior prototype starts with `// Adapted from a prior prototype, used with permission.` The original author's name and the original project name never appear in the repo.
- Follow docs/design/HIG-NOTES.md for UI changes. Metric units, no em dashes.

## 5. Scope

P03 onwards is decided after the owner reviews the P02 baseline. Until then, no feature changes.

## 6. Prior work disclosure

Adapted from a prior prototype, used with permission. The agent factory process (CLAUDE.md, AGENTS.md, FACTORY.md) comes from the owner's Recalled build (github.com/ShauryaS31/AppleHackathon, 23 October).
