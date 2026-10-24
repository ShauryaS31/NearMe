# P09: UI polish (native look, calm and readable)

| Field | Value |
|---|---|
| Status | todo |
| Window | Sat 24 Oct evening, after P07b, before P10 |
| Depends on | P07b |
| Assignee | codex |
| Branch | task/P09-ui-polish |

## Goal
NearMe looks like a polished, native Apple app: semantic system colours, one blue accent, native button styles, consistent type and spacing, and clear voice states. Visual and layout only: no change to routing, speech, guide content or the P07b dock structure.

## Read
AGENTS.md; docs/design/HIG-NOTES.md (all rules); docs/design/UI-WIDGETS-REPORT.md Part 1 sections 1 to 7 and the one-page brief (the source of the values below). Files: `NearMe/Views/Components/` (Theme, PrimaryButton, CaptionBubble, ProgressDotsView, ScreenScaffold, SessionDock, VoiceOrbView), `NearMe/Views/Onboarding/`, `NearMe/Views/Voice/` (VoiceSessionView, CoachView, SessionContainerView, OpeningPracticeView), `NearMe/Views/TripPlannerPractice/TripPlannerChrome.swift`, `NearMeTests/`.

Swift 6.4 rule: default arguments must not construct NearMe or test types or read MainActor statics. iOS 26.5 is the minimum: any iOS 27-only API sits behind `if #available(iOS 27, *)`.

Out of scope: the practice screens' own content (they imitate a trip planner app and keep their look), the P07b dock layout and target highlight, Settings and Privacy screens (P05, P06 build them and will follow Theme), widgets (P10).

## Acceptance criteria
### 1. Theme tokens (Theme.swift is the single source)
- [ ] Colours: only semantic system colours (`systemBackground`, `systemGroupedBackground`, `secondarySystemGroupedBackground`, `.primary`, `.secondary`) and one accent `Color(uiColor: .systemBlue)`. No hex or fixed RGB anywhere in NearMe's own views (grep `Color(red:` and `#colorLiteral` and hex helpers outside TripPlannerPractice: zero hits)
- [ ] Spacing tokens: screen inset 20 pt, section gap 24 pt, related gap 12 pt, card padding 20 pt, card corner radius 20 pt (continuous). Views use the tokens, not literals
- [ ] Type: instruction `.title2.weight(.semibold)`, captions and explanations `.body`, buttons `.headline`, Home talk button `.title2.weight(.semibold)`. No text below `.body` for anything the user must read; no uppercase-tracked status labels
- [ ] Reading surfaces (current instruction, captions, transcript) are opaque (`secondarySystemGroupedBackground`), never glass or `.ultraThinMaterial`

### 2. Buttons
- [ ] `PrimaryButton` becomes a thin wrapper over native styles: primary is `.borderedProminent` with the accent tint, secondary is `.bordered`; full width, minimum height 56 pt, grows with text, `Label(text, systemImage:)` always (symbol plus word). Remove custom fill painting
- [ ] One prominent button per screen at most
- [ ] At accessibility text sizes (`dynamicTypeSize.isAccessibilitySize`) side-by-side buttons stack vertically

### 3. Home (idle voice screen)
- [ ] Native title "NearMe" in a `NavigationStack`; toolbar button `gearshape` with visible label "Settings" only if a settings destination exists, otherwise omitted
- [ ] Heading "What would you like help with?" (`.title2`), one example request under it ("Try: help me send a photo to Mum"), the talk control, then a bordered "Type instead" (`keyboard`) and a row "Practise a train trip" (`tram.fill`)
- [ ] Talk control: full-width prominent button "Talk to NearMe" (`mic.fill`), minimum height 80 pt. It keeps exactly the P04b toggle behaviour, state labels and VoiceOver labels ("Start listening" / "Stop listening"); the large animated orb becomes a small state symbol beside the state text

### 4. Voice states (conversation screen)
- [ ] One stable state row above the transcript, symbol plus words, in the same position for every state: Ready `mic.fill` "Ready", Listening `mic.fill` "Listening... tap when you're done", Preparing `ProgressView` "Preparing your next step", Speaking `speaker.wave.2.fill` "Speaking", Paused "We paused here". Text, not colour, carries the state
- [ ] Transcript: "You said" label above the user's words, "NearMe" label above the reply; the current reply is the strongest text; earlier turns sit under a collapsed "Earlier conversation" disclosure
- [ ] Reduce Motion: no pulsing or scaling of the state symbol

### 5. Coach card (inside the P07b layout)
- [ ] Task title (for example "Send a photo"), "Step 3 of 6" (only when the total is known) with a determinate `ProgressView` of completed steps, the instruction in `.title2` on an opaque card with 20 pt padding
- [ ] Actions: prominent "Done" (`checkmark`), bordered "Repeat" (`arrow.counterclockwise`) and "I'm stuck" (`questionmark.circle`), "Open <App>" next to its explanation when the guide has one. Same actions and behaviour as P07; only presentation changes
- [ ] "I'm stuck" opens one large sheet (`.presentationDetents([.large])`) with a visible "Close" button; no stacked sheets

### 6. Onboarding
- [ ] Welcome and greeting merged into one screen if the greeting adds nothing unique: `hand.wave`, `.largeTitle` "A little help, one step at a time", two `.body` lines, prominent "Get started"
- [ ] Explainer: three rows, `mic.fill` "Tell NearMe what you want to do", `list.number` "Follow one step at a time", `hand.raised` "You stay in control", then prominent "Try it now" and bordered "Skip". Copy stays truthful (NearMe guides, never taps for you)
- [ ] All onboarding screens scroll at Accessibility XXXL with nothing clipped

### 7. Tests and checks (default run)
- [ ] Existing tests still pass; add a test that Theme exposes the tokens above and that `PrimaryButton` uses the stacked layout at an accessibility size (view-model or layout helper level, no snapshot library)
- [ ] Debug-only SwiftUI previews for Home, conversation (each state), coach card and onboarding at default size and `.accessibility5`, light and dark

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
```
Mac checks on the simulator: screenshots of Home, conversation (listening and speaking), coach card and onboarding at default size and Accessibility XXXL, light and dark; nothing clipped; one blue accent; Reduce Motion, Reduce Transparency, Bold Text and Button Shapes on: still readable and every control looks tappable; VoiceOver reads Home in order heading, example, Talk, Type instead, Practise.

<!-- Dev Reports and Reviews appended below. -->
