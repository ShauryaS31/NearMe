# P07b: Session layout and highlight

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct |
| Depends on | P07 |
| Assignee | codex |
| Branch | task/P07b-session-layout |

## Goal
The practice and coach screens get the whole screen; NearMe's own controls shrink to one compact dock at the bottom, and the step's target is unmistakable. Applies to the trip planner practice and the P07 coach screen.

## Read
AGENTS.md; docs/design/HIG-NOTES.md rules 2, 3, 5, 6, 7, 9, 10, 14. Files: `NearMe/Views/Voice/SessionContainerView.swift`, `VoiceSessionView.swift`, `NearMe/Views/TripPlannerPractice/` (all views, including the chrome and the tab bar), the P07 coach view(s), `NearMe/Views/Components/` (VoiceOrbView, VoiceOrbButton, CaptionBubble), `NearMe/ViewModels/TaskPlannerEngine.swift` (brain source, latency, voice and timing fields), `NearMeTests/`.

Swift 6.4 rule: default arguments must not construct NearMe or test types or read MainActor statics.

## Acceptance criteria
### 0. P07 review follow-ups (do these first)
- [ ] Rename the Codable guide model `Guide` (NearMe/Models/Guide.swift) to `HelpGuide` everywhere (types, loader, tests) and restore the plain `@Guide(...)` attribute in `JourneyIntent.swift` and `FoundationModelsBrain.swift` (no `@FoundationModels.Guide`), so the `@Generable` macro is certain to see the field descriptions
- [ ] TaskPlannerEngine.swift:431: on "Let's start again. Where would you like to go?" keep `tripRouteActive = true` (the user is still in practice), so a bare answer such as "Town Hall" stays in the trip flow. Test with the real keyword fallback router (not `PracticeOnlyTestRouter`)
- [ ] Practice card (`startPractice`, TaskPlannerEngine.swift:653-657): start the trip practice directly (route `practiceTripPlanner`, no model call) and stay in voice mode (do not call `useTypedInput`)
- [ ] Swift 6.4 type checker: split `HelpRouter.swift:69-78` (map, sorted with a ternary comparator, prefix, map) into explicitly typed steps; annotate the `Dictionary(uniqueKeysWithValues:)` in `GuidedCoachTests` as `[String: [Double]]`
- [ ] Nits: nearby-label fallback keeps the step's second sentence (for example set_alarm's 24-hour note, the torch's "The light stays on."); person extraction ignores "the bank", "the doctor" and other "the <noun>" phrases (only family words and capitalised names) and never rewrites "the person or number" to "Mum or number"; single-line text fields in `CoachView.swift:23,111` so Return submits; backgrounding during practice keeps the practice state; the Debug launch check accepts any valid `last_checked` date (YYYY-MM-DD), not only 2026-10-24; the loader reads only `.json` files
- [ ] If the owner's parallel P07 check reports a routing bug, it is added here as a numbered item in round 2

### 1. Compact bottom dock
- [ ] One `SessionDock` view at the bottom of practice and coach screens, inside the safe area (above the home indicator), never overlapping the practice screen's tab bar. Contents: a small mic button (44 x 44 pt minimum; tap to talk, tap again to finish, same states and VoiceOver labels as P04b), the current instruction in large text (`.title3` or larger, wraps, never truncates), and one "..." menu button (SF Symbol `ellipsis.circle`, label "More", 44 x 44 pt) holding Repeat, Slower, Type instead and End session
- [ ] A Stop button (SF Symbol `stop.fill` plus "Stop") appears in the dock only while NearMe is speaking, and stops speech at once (keeps the step, as in P04b)
- [ ] No floating orb, caption bubble or other NearMe control over the practice or coach content. The big orb stays only on the plain voice screen (home and conversation)
- [ ] At accessibility text sizes the dock grows upward and its instruction can scroll inside the dock (max about 40% of the screen height); the practice screen above keeps its own space

### 2. Practice screen above the dock
- [ ] The practice screen occupies all space above the dock. Its tab bar (and any bottom bar) stays fully visible and tappable on every step: the practice content scrolls if it does not fit; scale it down only if a fixed-layout practice screen cannot scroll (never below 85%)
- [ ] Check on the smallest current iPhone simulator and at Accessibility XXXL

### 3. Target highlight
- [ ] Each practice step's target element (from the step's target label, for example "Journey Planner") gets a thick accent ring (at least 4 pt, `Color.accentColor`, rounded to the element's shape) and a gentle pulse (scale or opacity, about 1.2 s period). With Reduce Motion on: no pulse, a static ring of 6 pt
- [ ] The rest of the practice screen is dimmed slightly (black overlay about 25% opacity, with a cut-out for the target so the target stays at full brightness). The dim never covers the dock. With Increase Contrast on, the ring is thicker (8 pt)
- [ ] Highlight follows the step on every practice step (one anchor per step; implement with `anchorPreference` or matched geometry, not hard-coded frames). VoiceOver: the target's hint says "This is the next step" and the dim layer is hidden from accessibility
- [ ] Coach screen (P07): no app screen to highlight; the dock and layout rules apply, and the step text shows the target label in bold

### 4. Debug badge (Debug builds only)
- [ ] Line 1, understanding of the last user turn: the brain that understood it ("On-device model", "On-device model + keyword fill" or "Keyword fallback") plus model ms, for example "Understood: On-device model, 840 ms"
- [ ] Line 2, voice: "Voice: ElevenLabs, first audio 1.06 s" or "Voice: System voice, first audio 0.4 s", plus STT ms
- [ ] "Template" is never shown as the brain: when the reply was a template, add "reply: template" after line 1 (for example "Understood: Keyword fallback | reply: template"). The engine keeps the understanding source separate from the reply source
- [ ] The badge sits in the top safe area, never over the dock or the practice tab bar

### 5. Tests (default run, fakes)
- [ ] Engine: understanding source survives a template reply; the badge text builder gives the two lines above
- [ ] Dock: Stop visible only while speaking; menu items call repeat, slower, type instead and end session
- [ ] Highlight: every practice step has a target label that exists on its screen (step-to-label table test)

## Verify (Mac and iPhone)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
bash scripts/mac-run.sh device --current
```
Mac/iPhone check: a screenshot of each practice step shows the dock, a visible highlight on the target, and an unobstructed, tappable tab bar; the same at the largest text size; the Debug badge shows "Understood: ..." and "Voice: ..." lines.

<!-- Dev Reports and Reviews appended below. -->
