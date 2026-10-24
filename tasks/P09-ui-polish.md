# P09: UI polish (native look, calm and readable)

| Field | Value |
|---|---|
| Status | review passed, awaiting owner merge and Mac gate (branch task/P09-ui-polish) |
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
- [ ] Native title "NearMe" in a `NavigationStack`; no Settings toolbar button in P09 (no settings destination exists yet; P05 adds the gear)
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
- [ ] `WelcomeView` and `GoodMorningView` merged into one Welcome screen (owner decision): `hand.wave`, the existing time-of-day greeting with the user's name (for example "Good morning, Shaurya") as a `.title2` line when a name is known, omitted when not, `.largeTitle` "A little help, one step at a time", two `.body` lines, prominent "Get started". The onboarding flow has one fewer step; no other step is lost
- [ ] Explainer: three rows, `mic.fill` "Tell NearMe what you want to do", `list.number` "Follow one step at a time", `hand.raised` "You stay in control", then prominent "Try it now" and bordered "Skip". Copy stays truthful (NearMe guides, never taps for you)
- [ ] All onboarding screens scroll at Accessibility XXXL with nothing clipped

### 7. Scope guard
- [ ] No changes under `NearMe/Services/`, `NearMe/Models/` or the guide JSON resources. `NearMe/ViewModels/` changes only for presentation state (no routing, speech or timing logic). Under `NearMe/Views/TripPlannerPractice/` only `TripPlannerChrome.swift` may change, and only to use Theme tokens for NearMe's own chrome
- [ ] P11 runs in parallel: do not touch `project.yml`, `NearMe/Info.plist`, `Shared/`, `NearMe/ViewModels/TaskPlannerEngine.swift`, `NearMe/Models/CoachSession.swift` or any coach engine or progress store file. Views may read existing engine properties. If an item cannot be done without one of these files, leave that item undone, explain it in the Dev Report and stop
- [ ] The Dev Report pastes the exact grep commands for 1.1 and their output (zero hits), and `git diff --stat main` for the scope guard

### 8. Tests and checks (default run)
- [ ] Existing tests still pass; add a test that Theme exposes the tokens above and that `PrimaryButton` uses the stacked layout at an accessibility size (view-model or layout helper level, no snapshot library)
- [ ] Debug-only SwiftUI previews for Home, conversation (each state), coach card and onboarding at default size and `.accessibility5`, light and dark

### 9. Owner additions (2026-10-24, from iPhone screenshots)
- [ ] A. No separate listening screen. Tapping the Home talk button listens in place on Home: the button becomes "Listening... tap when you're done" with a small waveform symbol (`waveform`), a bordered "Cancel" (`xmark`) appears under it, and the live transcript shows under a "You said" label. No purple orb, no uppercase tracked labels and no black cancel bar anywhere in the app (grep the Dev Report for evidence). Same P04b toggle behaviour and VoiceOver labels ("Start listening" / "Stop listening"); Cancel stops listening without submitting
- [ ] B. A reply that is not a guide step (the `CoachText.generalFallback` "I'm not sure about that one" reply, errors, the no-words message) never shows as a coach card, never shows "Step 1 of 1" and never shows Done. It shows on Home in the reply area under the "NearMe" label, with prominent "Try again" (`mic.fill`, starts listening) and bordered "Type instead" (`keyboard`). General guidance with real steps (one or more steps that are not the fallback text) still uses the coach card with its "General guidance: your screen may look different" label. Implement the decision as a pure presentation helper in Views (for example `CoachPresentation.kind(for:)`) using existing engine state and existing public commands. Only if that is impossible: a minimal additive engine change (new computed property or method, no change to existing logic), listed line by line in the Dev Report, because P11 is editing `TaskPlannerEngine.swift` in parallel. Tests: fallback session gives the Home reply kind; a general session with real steps and a guide session give the coach card kind
- [ ] C. Home looks designed, not blank: `systemGroupedBackground` page, content cards on `secondarySystemGroupedBackground` with the 20 pt continuous radius, the talk button as the clear hero (largest element, top of the content), Practice mode as a full row card with `tram.fill`, title, one-line explanation and a trailing `chevron.right`, spacing only from the 20/24/12 pt tokens. The coach card gets the same page and card treatment
- [ ] D. 5.2 "Open <App>", view-only (owner decision, replaces the blocked note in Dev Report r1): in the coach card, when the session's guide is a `HelpGuide` and `CoachAppLaunch.url(for: guide)` returns a URL, show a bordered "Open <guide.app>" button (`arrow.up.forward.app`) next to its explanation, opened with `@Environment(\.openURL)`. Hidden when the URL is nil. Tapping it does not change the step (the user still taps Done). No engine change; the engine's existing auto-open is untouched; no change to `CoachAppOpener.swift`. Put the show/hide decision in the same pure presentation helper as B. Tests: WhatsApp guide shows the button; general guidance hides it; a guide with no scheme hides it
- [ ] Scope rule update: the owner allows engine changes for presentation state only, under the conditions in B. All other P11 exclusions stay

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
```
Mac checks on the simulator: screenshots of Home, conversation (listening and speaking), coach card and onboarding at default size and Accessibility XXXL, light and dark; nothing clipped; one blue accent; Reduce Motion, Reduce Transparency, Bold Text and Button Shapes on: still readable and every control looks tappable; VoiceOver reads Home in order heading, example, Talk, Type instead, Practise.

<!-- Dev Reports and Reviews appended below. -->

## Lane log
- 2026-10-24 18:24 AEDT | P09 | claude (P09 lane) | dispatch r1 | worktree ../NearMe-p09, branch task/P09-ui-polish from origin/main e02d9ce; P11 files excluded in scope guard
- 2026-10-24 18:30 AEDT | P09 | codex | dev-report r1 | native UI polish, tests and preview matrix; manual Open app blocked by P11 scope; Mac gate pending

## Dev Report (round 1)
- Date: 2026-10-24 18:30 AEDT
- Changed files: `NearMe/App/AppCoordinator.swift`, `NearMe/App/ContentView.swift`; Components: `Theme.swift`, `PrimaryButton.swift`, `CaptionBubble.swift`, `ProgressDotsView.swift`, `ScreenScaffold.swift`, `SessionDock.swift`, `VoiceOrbView.swift`, new `UIPolishPreviews.swift`; Onboarding: `WelcomeView.swift`, `HowItWorksView.swift`, removed `GoodMorningView.swift`; Voice: `CoachView.swift`, `VoiceSessionView.swift`, `OpeningPracticeView.swift`; `NearMe/Views/TripPlannerPractice/TripPlannerChrome.swift`; new `NearMeTests/UIPolishTests.swift`; this task file.
- What I did: replaced the custom palette and orb with semantic colours, native buttons and static state symbols; added a native Home title and clearer voice transcript hierarchy; polished the coach card and presented existing stuck guidance in one large sheet; merged the greeting into Welcome; added nine presentation tests and 36 debug-only preview variants. Kept speech, session routing, guide data, engine timing, practice content and dock geometry intact. The only onboarding route adjustment skips the removed greeting screen.
- Acceptance criteria:
  - 1.1 Colours: implemented semantic backgrounds, primary/secondary text and system-blue tint in Theme. Exact grep commands and zero-hit results are below. The imitated practice app retains its own palette.
  - 1.2 Spacing: added named 20/24/12/20 pt screen/section/related/card tokens and retained the continuous 20 pt card radius. New layouts use these tokens. Existing P07b dock dimensions and practice-content legacy tokens are preserved under the explicit scope exclusions.
  - 1.3 Type: current replies/instructions use title2 semibold, captions/explanations use body, buttons use headline, Talk uses title2 semibold. Removed tracked uppercase status labels. The excluded dock instruction/target typography and debug-only diagnostics retain their existing styles; legacy caption/callout tokens remain solely for practice content.
  - 1.4 Reading surfaces: captions, transcript, coach instruction/help card and dock reading area use opaque secondarySystemGroupedBackground.
  - 2.1 PrimaryButton: native borderedProminent/bordered wrapper, required symbol-plus-word Label, accent tint, full width and at least 56 pt height, with vertical text growth; no custom fill.
  - 2.2 Prominence: one prominent action per presented screen. Conversation Talk becomes bordered while typed Send is prominent; coach Done is the only prominent coach action.
  - 2.3 Accessibility actions: AdaptiveButtonRow uses the tested PrimaryButtonLayout helper and stacks at every accessibility size. P07b dock controls retain their prescribed structure.
  - 3.1 Home navigation: NavigationStack with native NearMe title; no Settings button.
  - 3.2 Home content: requested heading, exact example, Talk, bordered Type instead and Practise a train trip, in that content order.
  - 3.3 Talk: full-width native prominent control, minimum 80 pt, existing userTappedToTalk callback, original start/stop VoiceOver labels and P04b instruction/disabled-state contract. Small static state symbol replaces the orb.
  - 4.1 Voice states: a single row above the transcript maps ready/listening/preparing/speaking/paused to the requested text and symbols; preparing uses ProgressView. Paused is local presentation state after the existing Stop action.
  - 4.2 Transcript: labels You said/NearMe; latest reply uses the strongest type; older turns are under an initially collapsed Earlier conversation disclosure. Read-only grouping preserves every older turn and avoids showing the prior reply as the response to new live words.
  - 4.3 Reduce Motion: state symbols never pulse or scale; onboarding and coach transitions respect Reduce Motion.
  - 5.1 Coach: guide title (or general request), known step count, determinate completed-step progress, title2 instruction and opaque 20 pt padded card. Progress at step 3 of 6 is 2 completed out of 6.
  - 5.2 Coach actions: Done/Repeat/I'm stuck retain their existing engine commands with requested symbols/styles. **Not completed: explicit Open <App> action/explanation.** The current engine has only private autoOpenCoachApp(generation:) and no view-callable manual-open action. Adding an equivalent action safely would require the expressly protected TaskPlannerEngine.swift or a new app-opening behavior. Left its existing automatic open/resume behavior unchanged and stopped at the scope boundary.
  - 5.3 Stuck sheet: one sheet owned by CoachView, large-only detent, visible Close in its toolbar and scrolling content. It observes the existing rewritten instruction and exposes existing Repeat/Slower/Stop commands. No nested sheets.
  - 6.1 Welcome: merged greeting and welcome, hand.wave, optional known-name time-of-day greeting, requested largeTitle and two body lines, Get started. Placeholder Friend and empty names omit the greeting. The coordinator now advances directly to the explainer; the protected AppRoute model retains its legacy case, mapped to Welcome for compatibility.
  - 6.2 Explainer: requested three labelled rows, truthful guidance copy, prominent Try it now and bordered Skip; both use the existing transition to the session Home.
  - 6.3 Scrolling: both onboarding presentations use the scrolling scaffold and wrapping text; default/accessibility5 light/dark previews supplied. Actual clipping checks await the Mac.
  - 7.1 Scope: no Services, Models, ViewModels or guide-resource changes. Only TripPlannerChrome.swift changed within TripPlannerPractice, limited to Theme tokens for the top chrome. Practice tab/content code and target highlight untouched.
  - 7.2 P11 guard: no project.yml, Info.plist, Shared, engine or progress-store edits. The manual Open app item remains blocked as described above. No merge or next task.
  - 7.3 Evidence: exact greps and git diff --stat main output below. PLAN/LOG differences shown against main are pre-existing branch divergence, not working-tree edits.
  - 8.1 Tests: added nine tests covering tokens, every accessibility stacking size, state precedence/VoiceOver labels, transcript retention and live/final transcript handling, coach completed-step progress, onboarding transitions and greeting rules. **Not run:** this Windows machine has no Swift or Xcode; existing/new tests are not claimed to pass.
  - 8.2 Previews: 36 DEBUG-only previews cover Home, conversation in all five states, coach card, Welcome and explainer, each at default Large/accessibility5 in light/dark. Presentation-only fixtures do not start speech, models or permission prompts. Previews have not been rendered here.
- Verify commands run and results:
  - `git diff --check`: no output, exit 0.
  - `Get-Command swift,xcodebuild,bash,python -ErrorAction SilentlyContinue`: Swift and xcodebuild absent; bash/python available.
  - `git diff --name-only HEAD -- NearMe/Services NearMe/Models NearMe/ViewModels Shared project.yml NearMe/Info.plist NearMe/Resources/guides docs/PLAN.md docs/LOG.md docs/SPEC.md AGENTS.md`: no output.
  - `git diff --name-only main HEAD -- docs/PLAN.md docs/LOG.md`: outputs docs/LOG.md and docs/PLAN.md, confirming the baseline branch divergence.
  - Reviewed changed call sites, preserved callbacks, default arguments and preview guards. No new force unwraps, NearMe/test constructions or MainActor-static reads in default arguments; transcript operations are split into typed steps.
  - `rg` is not installed, so git grep and PowerShell Select-String were used. The latter also scanned untracked view files and found no prohibited colour patterns.
  - Mac commands below were **not run** here.
- Mac test steps for the owner:
  1. After the manager commits this work, use the Mac checkout of `task/P09-ui-polish`. In its repository root run `bash scripts/mac-run.sh test --current`. Require all existing tests and UIPolishTests to pass; inspect `build/xcodebuild.log` on failure. Then run `bash scripts/mac-run.sh quick`.
  2. Open `NearMe.xcodeproj` in Xcode 27.1, select the NearMe scheme and open `NearMe/Views/Components/UIPolishPreviews.swift`. Render all 36 named previews; check wrapping, native button boundaries, state placement and one prominent action per screen. Also run on an iOS 26.5 simulator to verify the minimum OS.
  3. On a fresh launch follow Welcome > Get started > explainer > Try it now. Restart and test Skip. Confirm there is no separate greeting screen and Home has the requested content order. Preview the known-name greeting; production currently defaults to the placeholder Friend.
  4. Tap Talk, grant microphone access if prompted, speak a request and tap again to finish. Verify Start listening/Stop listening labels, disabled finishing/preparing controls, speaking interruption, Type instead/Send, error/place-suggestion controls and unchanged cancel/end behavior. During speech tap Stop: speech stops, the current reply remains, and the row reads We paused here. Submit another turn and expand Earlier conversation to check earlier turns remain available.
  5. From Home type `Help me send a photo to Mum on WhatsApp`. Return to NearMe after the existing automatic app handoff if installed. Verify title, count and completed-step progress; Done advances once, Repeat leaves progress unchanged, and I'm stuck opens a single large sheet showing the existing rewritten guidance. Test Close, Slower and Stop; reopen the sheet and confirm there is no sheet stack. The manual Open app button is intentionally absent pending the protected-engine follow-up.
  6. Select Practise a train trip and complete a journey. Verify the P07b dock remains at the bottom, its typing/Stop/menu controls work, and the target highlight still behaves as before.
  7. Capture Home, conversation while listening and speaking, coach, Welcome and explainer at default text size in both appearances. In Simulator Settings > Accessibility > Display & Text Size > Larger Text, enable Larger Accessibility Sizes and move the slider fully right (Accessibility XXXL); repeat all screens in light/dark, scroll to every action and check nothing clips. Use `mkdir -p build/p09-screenshots` then e.g. `xcrun simctl io booted screenshot build/p09-screenshots/home-default-light.png`, changing the filename for each screen/size/appearance.
  8. Enable Reduce Motion, Reduce Transparency, Bold Text and Button Shapes in Simulator accessibility settings; repeat the screens and verify opaque readable text, no state pulsing/scaling, clear button boundaries and reachable controls. Check Increase Contrast and measure rendered text contrast against the HIG-notes targets.
  9. Enable VoiceOver and verify Home content order: heading, example, Talk, Type instead, Practise; the Talk hint/state text may follow the control. Verify every control is labelled, current reply/instruction is readable, and the coach sheet Close and Stop remain reachable at the largest size.
- Not done / risks / questions: manual Open app action blocked by P11 scope guard; Mac build/tests, rendered previews, screenshots, contrast and assistive-technology checks remain pending. AppCoordinator/ContentView changed only as needed to merge onboarding and respect system appearance/motion. P07b dock dimensions and target styling remain excluded. No new APIs requiring iOS 27 were introduced. No edits to docs/PLAN.md or docs/LOG.md.
- Commit disposition: Git staging succeeded in this worktree; local Git writes are available. Prepared for commit `N09: Polish native voice and onboarding UI`; no merge or push.

### Colour grep evidence (PowerShell; repository root)

```powershell
git grep -n -E 'Color[[:space:]]*\([[:space:]]*red:|#colorLiteral' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```

Output: none (zero hits; exit 1, git grep's no-match result).

```powershell
git grep -n -E '(Color|UIColor)[[:space:]]*\([[:space:]]*hex:|init[[:space:]]*\([[:space:]]*hex:|0x[0-9A-Fa-f]+|#[0-9A-Fa-f]{6,8}' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```

Output: none (zero hits; exit 1).

### Scope evidence

Exact command: `git diff --stat main`. Output captured before appending this report:

```text
 NearMe/App/AppCoordinator.swift                    |   4 -
 NearMe/App/ContentView.swift                       |  12 +-
 NearMe/Views/Components/CaptionBubble.swift        |  53 +---
 NearMe/Views/Components/PrimaryButton.swift        |  54 ++--
 NearMe/Views/Components/ProgressDotsView.swift     |  33 +--
 NearMe/Views/Components/ScreenScaffold.swift       |  13 +-
 NearMe/Views/Components/SessionDock.swift          |   6 +-
 NearMe/Views/Components/Theme.swift                |  36 ++-
 NearMe/Views/Components/VoiceOrbView.swift         | 142 ++++-----
 NearMe/Views/Onboarding/GoodMorningView.swift      |  64 -----
 NearMe/Views/Onboarding/HowItWorksView.swift        |  61 ++--
 NearMe/Views/Onboarding/WelcomeView.swift          |  91 +++---
 .../TripPlannerPractice/TripPlannerChrome.swift    |  10 +-
 NearMe/Views/Voice/CoachView.swift                 | 193 ++++++++-----
 NearMe/Views/Voice/OpeningPracticeView.swift       |  19 +-
 NearMe/Views/Voice/VoiceSessionView.swift          | 318 +++++++++++----------
 docs/LOG.md                                        |   1 -
 docs/PLAN.md                                       |   3 +-
 tasks/P09-ui-polish.md                             |   6 +-
 19 files changed, 539 insertions(+), 580 deletions(-)
```

The docs/PLAN.md and docs/LOG.md rows are differences already present between this lane's HEAD and main; the working-tree scope check against HEAD is empty for both. Untracked additions are not included in git diff --stat: `NearMe/Views/Components/UIPolishPreviews.swift` and `NearMeTests/UIPolishTests.swift` (confirmed with `git ls-files --others --exclude-standard`). This report and its lane-log entry are also additional to the captured snapshot.
- 2026-10-24 18:33 AEDT | P09 | owner | decision | additions A (listen in place on Home), B (non-step replies on Home, not a coach card), C (grouped Home and coach card) added as section 9; for round 2
- 2026-10-24 18:36 AEDT | P09 | owner | decision | 5.2 Open <App> done view-only via CoachAppLaunch.url(for:) and openURL, step unchanged on tap; added as 9.D for round 2

## Review (round 1)
CHANGES. Static review (no Swift toolchain here). 1.1 greps zero hits; scope guard and P11 exclusions respected; previews Debug-only; welcome merge and explainer copy correct. Fix these, then do section 9 (owner additions A to D) in the same round:

1. 4.3 / HIG rule 9: `VoiceStateRow` (`VoiceOrbView.swift:118-119`) always shows an animated `ProgressView` for Preparing (also in the stuck sheet, `CoachView.swift:176`). With `accessibilityReduceMotion` show the static `hourglass` symbol instead, as `ProgressDotsView` does.
2. 3.3 VoiceOver order: the visible state text under the talk button (`VoiceOrbView.swift:43-47`) is read between Talk and Type instead and repeats the hint. Hide it from accessibility (the button's label and value carry the state), so Home reads heading, example, Talk, Type instead, Practise.
3. 4.1 / owner addition A: the listening text appears twice (state row and under the button). With A, the talk button itself shows "Listening... tap when you're done"; show each state's words exactly once on screen.
4. 1.3: the coach task title (`CoachView.swift:129-131`) uses the same `.title2.weight(.semibold)` as the instruction. Make the title `.headline` so the instruction is the strongest text.
5. Swift 6.4 default argument rule: `var emphasis: ButtonEmphasis = .primary` (`PrimaryButton.swift:10`, `VoiceOrbView.swift:36`). Declare `nonisolated enum ButtonEmphasis: Sendable` so the default is certain to compile.
6. Voice Control: the talk button shows "Talk to NearMe" while its accessibility label is "Start listening". Keep the labels and add `.accessibilityInputLabels(["Talk to NearMe", "Start listening"])` (and the equivalent for the listening state).
7. Replace the duplicated "Friend" literal (`WelcomeView.swift:22`, `AppCoordinator.swift:9`) with one shared constant such as `AppCoordinator.placeholderName`.
8. `CaptionBubble` is no longer used: delete the file (and any test or preview that names it).

Mac gate (PENDING MAC): the new Stop on the conversation screen (`VoiceSessionView.swift:81-86`) must not change cancel or barge-in; the dock mic symbol is now `mic.fill` when listening (check it still reads clearly with its state text).
- 2026-10-24 18:37 AEDT | P09 | claude (P09 lane) | review r1 CHANGES | Reduce Motion spinner, VoiceOver order, duplicate state text, coach title weight, nonisolated ButtonEmphasis, input labels, placeholder name, delete CaptionBubble; plus owner 9.A-D; dispatch r2


## Dev Report (round 2)
- Date: 2026-10-24 18:42 AEDT
- Changed files: `NearMe/App/AppCoordinator.swift`; Components: deleted `CaptionBubble.swift`, updated `PrimaryButton.swift`, `ScreenScaffold.swift`, `VoiceOrbView.swift`, `UIPolishPreviews.swift`; Onboarding: `WelcomeView.swift`; Voice: new `CoachPresentation.swift` and `HelpHomeView.swift`, updated `CoachView.swift`, `SessionContainerView.swift`, `VoiceSessionView.swift`; `NearMeTests/UIPolishTests.swift`; this task file.
- What I did: addressed all eight round 1 review items and owner additions 9.A-D using views and existing public engine commands. Home now owns voice input, typed input, current replies and practice prompts. Removed the separate conversation-screen implementation, retaining its transcript/history and place-suggestion components. Added a pure presentation helper for coach eligibility, non-step replies and Open app visibility. No engine changes, including no additive changes under the 9.B exception. No changes to CoachAppOpener.swift or automatic opening.
- Review (round 1), each numbered point:
  1. Preparing uses a static `hourglass` when Reduce Motion is enabled. Both Home and the stuck sheet use the corrected `VoiceStateRow`; the determinate step progress remains determinate.
  2. Removed the redundant visible instruction row under Talk, so it cannot create an extra VoiceOver stop. The original Start listening/Stop listening labels remain, and the button value carries its instruction. Idle Home's content order remains heading, example, Talk, Type instead, Practise.
  3. Listening words appear once, inside the Talk button with `waveform`. Home omits the separate state row during listening. Other active states have one row above the transcript; there is no separate listening screen.
  4. Coach task title is now `.headline`; current instruction remains title2 semibold.
  5. `ButtonEmphasis` is exactly `nonisolated enum ButtonEmphasis: Sendable`, making both button default values isolation-safe. No new default arguments construct app/test types or read MainActor statics; view configuration uses resolved stored properties. No new force unwraps or long tuple chains.
  6. Added Voice Control input labels containing the visible title and original listening action: Talk to NearMe/Start listening, Listening... tap when you're done/Stop listening, and Try again/Start listening.
  7. Added `AppCoordinator.placeholderName`; the coordinator, welcome filter and test all use it. Only its declaration contains the placeholder literal.
  8. Deleted CaptionBubble.swift; no source/test/preview references remain. Removed the now-unused standalone state-symbol view as part of eliminating the duplicate row.
- Owner additions:
  - 9.A: SessionContainerView selects the same Home view throughout capture/preparation/replies. Talk still calls `userTappedToTalk()` for both start and finish, with the existing disabled-state contract. Listening has a waveform and the exact requested words; bordered Cancel (`xmark`) sits directly underneath and calls `cancelCurrentAction()`, which discards rather than submits capture. Live words appear under You said. No speech/timing implementation was changed.
  - 9.B: `CoachPresentation.kind(for:)` returns Home reply for fallback, empty and absent sessions, and coach card for guide sessions and real general steps (including one real step). An explicit error also selects Home. The non-step text appears under NearMe with prominent Try again and bordered Type instead, without step count or Done. Before retrying/typing from a non-step coach session, the view uses `cancelCurrentAction()` so the engine will route a new request instead of interpreting it as a coach command. Real general steps retain the coach card and now show the exact general-guidance label. Added deterministic helper tests for these cases, errors and the actual no-speech diagnostic.
  - 9.C: Home uses systemGroupedBackground, opaque secondarySystemGroupedBackground cards, continuous 20 pt corners and only the 20/24/12 pt spacing tokens. Talk is the largest control at the top of the content, after its heading/example. Practice is a full-width card with tram.fill, title, short explanation and chevron.right; text wraps at accessibility sizes. Coach retains the same grouped page/card treatment.
  - 9.D: `CoachPresentation.appLaunch(for:)` returns app name/URL only for a HelpGuide accepted by the existing `CoachAppLaunch.url(for:)`. Coach displays a bordered Open <App> (`arrow.up.forward.app`) beside its explanation, stacking at accessibility sizes. Its sole action is `@Environment(\.openURL)`; it sends no engine command and does not change the step. Tests cover WhatsApp, general guidance and a real bundled guide without a scheme. The engine's automatic handoff/resume and CoachAppOpener.swift are untouched.
- Acceptance criteria:
  - 1.1-1.4: semantic colours and existing Theme tokens retained, new Home surfaces opaque, title hierarchy corrected. Exact zero-hit greps below; Python also scanned the new, untracked Swift files with the same colour patterns and found zero hits.
  - 2.1-2.3: native button styles and minimum heights retained. Home has one prominent action: Talk/Try again, or Send during ordinary typing. If an error still shows while typing, Try again stays prominent and Send is bordered. Open app/explanation use AdaptiveButtonRow and stack at accessibility sizes.
  - 3.1-3.3: native NearMe NavigationStack, requested heading/example, hero Talk, bordered Type instead and expanded practice row. No Settings destination added. Original microphone commands and accessibility action labels retained.
  - 4.1-4.3: single state presentation, labelled current user/reply and collapsed earlier history. Owner 9.A supersedes the separate listening state row. Error overrides preserve the previous prompt in Earlier conversation, with a regression test. Reduce Motion uses the static preparing symbol in both places.
  - 5.1-5.3: known step count/completed-step progress and 20 pt instruction card retained; task title reduced to headline. Done/Repeat/I'm stuck commands unchanged. Manual Open app completed per 9.D. Existing single large stuck sheet, Close, Slower and Stop retained.
  - 6.1-6.3: merged greeting/Welcome and truthful explainer retained; shared placeholder constant removes duplicate name logic. Scrolling onboarding previews remain; actual accessibility clipping checks await the Mac.
  - 7.1-7.3: zero round 2 changes to Services, Models, ViewModels, guide JSON, Shared, project.yml, Info.plist, TripPlannerPractice, SPEC, PLAN, LOG or AGENTS. No engine exception used. Main comparison includes pre-existing lane divergence in PLAN, LOG and P07d; the separate HEAD scope check is empty.
  - 8.1-8.2: UIPolishTests now has 18 tests (9 added in this round). The 45 DEBUG-only previews include all Home/conversation states, fallback reply, general/guide coach, onboarding, default/accessibility5, light/dark, plus Reduce Motion preparation. Preview fixtures do not run the engine or request speech/permissions. Tests and previews have NOT been run/rendered here.
- Verify commands run and results:
  - `git diff --check`: no output, exit 0 after normalising changed Swift files to LF.
  - `git diff --name-only HEAD -- NearMe/Services NearMe/Models NearMe/ViewModels Shared project.yml NearMe/Info.plist NearMe/Resources NearMe/Views/TripPlannerPractice docs/PLAN.md docs/LOG.md docs/SPEC.md AGENTS.md`: no output, exit 0.
  - `git diff --name-only main HEAD -- docs/PLAN.md docs/LOG.md tasks/P07d-router-keyword-override.md`: outputs those three paths; these are pre-existing branch differences, not this round's edits.
  - `git grep -n -E 'CaptionBubble|VoiceSessionView\(|ConversationScreen\(' -- NearMe NearMeTests`: no output, zero hits (exit 1).
  - Python `shutil.which('swift')` and `shutil.which('xcodebuild')`: both `None`. This Windows machine has no Swift or Xcode. No build/test success is claimed. `rg` invocation was unavailable in the shell, so git grep and Python were used.
  - Static call-site review: Home start/finish uses userTappedToTalk, Cancel uses cancelCurrentAction, Stop uses stopSessionSpeech, typed submission uses canSubmitTypedInput/submitTypedInput, manual Open uses only openURL. Checked new files as well as tracked diffs.
- Mac test steps for the owner:
  1. Use the committed `task/P09-ui-polish` checkout (or the manager's commit of these files). From its repository root run `bash scripts/mac-run.sh test --current`, then `bash scripts/mac-run.sh quick`. Require all tests, including all 18 UIPolishTests and existing speech/cancel/coach tests, to pass. On failure inspect `build/xcodebuild.log`. Do not run the default main-switching command. These commands were not run here.
  2. Open `NearMe.xcodeproj` in Xcode 27.1, select NearMe and render all 45 previews in `NearMe/Views/Components/UIPolishPreviews.swift`. Check especially Conversation listening, Home reply, Coach Open app, general guidance and Home preparing / Reduce Motion. Repeat runtime checks on an iOS 26.5 simulator.
  3. Launch fresh: Welcome > Get started > Try it now (also repeat using Skip). Verify the single Welcome and grouped Home. With VoiceOver, read heading, example, Talk, Type instead, Practise in order. With Voice Control, activate Talk to NearMe and the listening label/Stop listening. Check the action label remains Start listening or Stop listening.
  4. Tap Talk, grant access if needed, say a request and tap the listening button to submit. Confirm Home and its native title remain in place, the waveform/listening text appears once, Cancel is bordered immediately underneath, and partial words appear under You said. Start another turn, say words, then tap Cancel; wait past the normal endpoint and confirm no request/reply/guide is submitted. Repeat during microphone preparation and while finishing.
  5. Tap Talk and finish with no words. Confirm the no-words diagnostic appears under NearMe on Home with prominent Try again and bordered Type instead, without a step count or Done. Exercise a microphone-denied/unavailable error, then Type instead and submit. Check only one prominent control, reachable text entry and no discarded typed draft during ordinary partial updates. Exercise fallback on a simulator without an available model and inspect the deterministic Home reply preview/tests as well. Retry a fallback by voice and by typing a known guide request; confirm it routes as a new request rather than replying with coach-command help.
  6. Submit `Help me send a photo to Mum on WhatsApp`. Allow the existing automatic handoff if available, then return. Record the current step, tap Open WhatsApp and return again: the step number must be unchanged by the manual button. Tap Done to advance once. Check a no-scheme guide (for example Connect to Wi-Fi) has no Open button. Use the general-coach preview/helper tests to confirm real general steps retain Done and the general-guidance label.
  7. During reply speech tap Stop: speech stops, reply remains, We paused here appears. Tap Talk during speech to verify barge-in still works. Exercise Repeat, I'm stuck, Close, Slower and Stop; the sheet must stay large with no stacked sheet, and preparing must show hourglass with Reduce Motion. Complete practice and check place suggestions, typed answers, End session, unchanged dock geometry/highlight, and the dock's mic.fill plus listening words.
  8. At default size and Accessibility XXXL (Settings > Accessibility > Display & Text Size > Larger Text, Larger Accessibility Sizes on, slider fully right), capture Home idle/listening/speaking/error, coach, stuck sheet and onboarding in light/dark. Use `mkdir -p build/p09-screenshots` then `xcrun simctl io booted screenshot build/p09-screenshots/home-listening-accessibility5-dark.png`, changing each filename. Scroll to every action; check no clipping, wrapping Open controls and readable practice explanation.
  9. Repeat with Reduce Motion, Reduce Transparency, Bold Text, Button Shapes and Increase Contrast. Verify static preparation, opaque text surfaces and tappable boundaries; check rendered contrast against HIG notes. Confirm no duplicate VoiceOver state stop beneath Talk and the visible labels work with Voice Control.
- Not done / risks / questions: Mac compilation, test execution, rendered previews, screenshots, contrast and assistive-technology checks remain PENDING MAC. The review's Stop/cancel/barge-in and dock mic checks remain part of that gate. Actual external-app availability/launch is owned by the OS; button visibility follows exactly CoachAppLaunch.url(for:), not an added availability probe. No P11 file, engine logic, service, model, guide resource, practice content or protected doc was changed. No merge/push/next task.
- Commit disposition: Git staging succeeded on `task/P09-ui-polish`; committing the listed files as `N09: Keep voice replies on Home and finish UI review`. No merge or push.

### Round 2 colour and owner-addition grep evidence

```powershell
git grep -n -E 'Color[[:space:]]*\([[:space:]]*red:|#colorLiteral' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```
Output: none (zero hits, exit 1).

```powershell
git grep -n -E '(Color|UIColor)[[:space:]]*\([[:space:]]*hex:|init[[:space:]]*\([[:space:]]*hex:|0x[0-9A-Fa-f]+|#[0-9A-Fa-f]{6,8}' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```
Output: none (zero hits, exit 1).

```powershell
git grep -n -E '\.purple|\.black|\.tracking\(|\.kerning\(|\.uppercased\(' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```
Output: none (zero hits, exit 1). Python scanning all own-view Swift files, including new files, also found zero matches. A whole-app search found only `.black.opacity(0.25)` in the explicitly excluded practice target highlight (`PracticeHighlight.swift:78`), not a Cancel control. There is no purple orb, tracked uppercase label or black Cancel bar.

### Round 2 scope evidence

Exact command: `git diff --stat main`. Output before appending this report/staging new files:

```text
 NearMe/App/AppCoordinator.swift                    |   7 +-
 NearMe/App/ContentView.swift                       |  12 +-
 NearMe/Views/Components/CaptionBubble.swift        |  60 ----
 NearMe/Views/Components/PrimaryButton.swift        |  54 ++--
 NearMe/Views/Components/ProgressDotsView.swift     |  33 +-
 NearMe/Views/Components/ScreenScaffold.swift       |  16 +-
 NearMe/Views/Components/SessionDock.swift          |   6 +-
 NearMe/Views/Components/Theme.swift                |  36 ++-
 NearMe/Views/Components/UIPolishPreviews.swift     | 358 +++++++++++++++++++++
 NearMe/Views/Components/VoiceOrbView.swift         | 140 ++++----
 NearMe/Views/Onboarding/GoodMorningView.swift      |  64 ----
 NearMe/Views/Onboarding/HowItWorksView.swift       |  61 ++--
 NearMe/Views/Onboarding/WelcomeView.swift          |  90 +++---
 .../TripPlannerPractice/TripPlannerChrome.swift    |  10 +-
 NearMe/Views/Voice/CoachView.swift                 | 189 ++++++-----
 NearMe/Views/Voice/OpeningPracticeView.swift       |  19 +-
 NearMe/Views/Voice/SessionContainerView.swift      |   8 +-
 NearMe/Views/Voice/VoiceSessionView.swift          | 263 +++++----------
 NearMeTests/UIPolishTests.swift                    | 216 +++++++++++++
 docs/LOG.md                                        |   2 -
 docs/PLAN.md                                       |   4 +-
 tasks/P07d-router-keyword-override.md              |  37 ---
 tasks/P09-ui-polish.md                             | 124 ++++++-
 23 files changed, 1120 insertions(+), 689 deletions(-)
```

New files not included in that unstaged stat: `NearMe/Views/Voice/CoachPresentation.swift` and `NearMe/Views/Voice/HelpHomeView.swift`, confirmed by `git ls-files --others --exclude-standard`. The report itself is additional to this captured stat. PLAN/LOG/P07d rows are pre-existing branch divergence as demonstrated above.

- 2026-10-24 18:42 AEDT | P09 | codex | dev-report r2 | addressed review 1-8 and owner 9.A-D in views; Home listening/replies, grouped cards and manual Open app; no engine edits; Mac gate pending

## Review (round 2)
CHANGES (final round). Review (round 1) items 1-8 MET; 9.A, 9.C, 9.D MET statically; scope clean (no Services, Models, ViewModels, Shared, project.yml or Info.plist changes). 9.B regresses a live guide:

1. Guide progress wiped after an error. `CoachPresentation.showsCoachCard` returns false whenever `lastErrorMessage != nil`, even for a guide or real general session, so a no-words turn (engine sets the error) or an unrecognised coach command swaps the coach card for Home; Home's Try again / Type instead then call `cancelCurrentAction()`, which clears the coach and the P07 progress store. Sequence: WhatsApp guide step 3, tap dock mic, say nothing, Try again: guide gone. Fix: `showsCoachCard` = `kind(for: session) == .coachCard` (ignore the error), so a real coach keeps the card and shows its error in the dock as on main; the Home reply shows an error only when there is no coach or the session kind is `.homeReply`. In Home's talk and type actions, cancel only when the coach exists and its kind is `.homeReply`. Replace `testErrorsAndNoWordsUseHomeReplyEvenWithExistingCoach` with tests that a guide session plus an error, and a real general session plus an error, still give the coach card, and that no coach plus an error gives the Home reply.
2. Real general session leaves the card on I'm stuck. `kind(for:)` returns `.homeReply` when `session.text == generalFallback`, but `generalStuck` falls back to exactly that text and writes it into `coach.text`, so with no model the coach card (and the open stuck sheet) disappears mid-session. Fix: decide from `guide` and `generalSteps` only (remove the `currentText` check). Delete or invert `testFallbackRewriteOfGeneralStepsUsesHomeReply`.
3. Compile error: `UIPolishPreviews.swift:354` `.environment(\.accessibilityReduceMotion, true)`: that key is read-only, so every Debug build (and the test run) fails. Drop that override; if a Reduce Motion preview is wanted, give `VoiceStateRow` an internal `reduceMotionOverride: Bool?` used only by previews.
4. 9.A: Cancel shows whenever `!engine.isHome` (`HelpHomeView.swift`), including idle and reply states. Show it only while listening, finishing, starting to listen or preparing.

Follow-up for the manager (not P09): after backgrounding with a fallback session held, `appBecameActive` calls `resumeCoach()` and would say "You were on step 1: I'm not sure about that one". Engine behaviour; candidate task after P11.
- 2026-10-24 18:46 AEDT | P09 | claude (P09 lane) | review r2 CHANGES | error during a guide wipes progress; I'm stuck fallback drops the card; read-only Reduce Motion preview breaks Debug build; Cancel visible when idle; dispatch r3 (final)

## Dev Report (round 3)
- Date: 2026-10-24 18:47 AEDT
- Changed files: `NearMe/Views/Voice/CoachPresentation.swift`, `NearMe/Views/Voice/HelpHomeView.swift`, `NearMe/Views/Components/UIPolishPreviews.swift`, `NearMeTests/UIPolishTests.swift`, this task file.
- What I did: addressed Review (round 2) items 1-4 only. Kept all changes in view presentation, preview fixtures and regression tests. No engine, service, model, progress-store or protected-document edits.
- Acceptance criteria / Review (round 2):
  1. `showsCoachCard` now depends solely on `kind(for:)`, ignoring errors. `reply` returns errors only for the Home-reply kind (including no coach). Home's Talk and Type actions cancel an existing coach only when its kind is `.homeReply`. Real guide/general sessions therefore stay in CoachView and use the existing dock error display. Replaced the old error regression test with separate guide-at-step-3, real-general and no-coach tests covering errors and the actual no-words diagnostic; added fallback-session error coverage.
  2. Removed the current-text fallback check. Classification now uses only the guide and stored general steps. Inverted the rewrite test: a real general session remains a coach card after its current text changes to `CoachText.generalFallback`, preserving the view that owns the stuck sheet.
  3. Removed the preview that wrote the read-only `accessibilityReduceMotion` environment key. No override or new default argument was introduced. The existing system-driven Reduce Motion behavior is unchanged; 44 DEBUG previews remain, including preparation in the default/accessibility5 light/dark matrix.
  4. Home and preview fixtures show Cancel only for listening or preparing activity. The existing resolver includes finishing, starting the microphone, thinking and speech preparation in preparing. Ready, speaking and paused states do not show Cancel. Native Cancel behavior is unchanged.
- Other acceptance criteria: retained the existing Theme, buttons, onboarding, coach actions and Home transcript behavior. No new force unwraps, app/test-type default arguments, MainActor-static default arguments, or environment writes. SwiftUI bodies remain split into the existing small components.
- Verify commands run and results:
  - `git diff --check`: no output, exit 0.
  - `git diff --name-only HEAD -- NearMe/Services NearMe/Models NearMe/ViewModels Shared project.yml NearMe/Info.plist NearMe/Resources NearMe/Views/TripPlannerPractice docs/PLAN.md docs/LOG.md docs/SPEC.md AGENTS.md`: no output, exit 0.
  - `git grep -n -F '.environment(' -- NearMe/Views/Components/UIPolishPreviews.swift`: no output, zero hits (exit 1).
  - `(Select-String -Path NearMeTests/UIPolishTests.swift -Pattern '    func test').Count`: 21. `(Select-String -Path NearMe/Views/Components/UIPolishPreviews.swift -Pattern '^#Preview').Count`: 44. These are source counts, not execution results.
  - `Get-Command swift,xcodebuild -ErrorAction SilentlyContinue`: no output, exit 1. This Windows machine has no Swift or Xcode. No Swift compilation, test execution or preview rendering was run or claimed to pass. `rg` was unavailable when invoked; used git grep and PowerShell instead.
  - Reviewed the complete four-file code diff and the existing activity resolver and dock error rendering. Exact colour and scope evidence follows.
- Mac test steps for the owner:
  1. In the `task/P09-ui-polish` checkout containing these changes, run `bash scripts/mac-run.sh test --current`, then `bash scripts/mac-run.sh quick` from the repository root. Require all tests, including the 21 UIPolishTests, to pass. Inspect `build/xcodebuild.log` on failure. Do not use the default command that switches to main.
  2. Open `NearMe.xcodeproj` in Xcode, select NearMe, and render the 44 previews in `NearMe/Views/Components/UIPolishPreviews.swift`. Confirm Debug builds without the read-only environment error. Check Home ready/listening/preparing/speaking/paused and fallback reply at default/accessibility5 in light/dark; Cancel must appear only in listening/preparing previews.
  3. On an iOS 26.5 simulator/device, ask to send a photo on WhatsApp, advance to step 3, tap the dock microphone, say nothing, then tap it to finish. Confirm the coach card stays at step 3 and the dock displays the no-words error. Retry using the dock microphone and Type instead; neither must clear the guide. Repeat with an unrecognised coach command. Background and return to confirm saved guide progress remains.
  4. In a real general-guidance session, cause the same no-words/error conditions and confirm the coach remains. Exercise I'm stuck when the model is unavailable and the rewrite returns the fallback text: the coach card and large stuck sheet must remain, and Close must return to the same session. The deterministic rewrite test covers the classification even when this runtime failure is difficult to induce.
  5. With no coach, submit no words and confirm the Home error, Try again and Type instead still work. Exercise a fallback-only session and retry by voice and typing; it must start a fresh request. No coach step count or Done should appear on Home.
  6. On Home verify Cancel during microphone startup, listening, finishing and answer/speech preparation. Cancel during capture must discard the turn. Verify no Cancel while idle, showing an idle reply, speaking or paused. Enable Settings > Accessibility > Motion > Reduce Motion and confirm preparation uses the static hourglass. Recheck Stop and barge-in, plus large-text scrolling.
- Not done / risks / questions: all four review fixes are implemented; compilation, tests, rendered layout and on-device progress/cancel checks remain PENDING MAC. The manager's fallback-session background/resume follow-up is engine behavior outside P09 and remains untouched. No merge, push or next task. docs/PLAN.md and docs/LOG.md were not edited; the requested lane-log line is appended to this task instead.

### Round 3 colour evidence

```powershell
git grep -n -E 'Color[[:space:]]*\([[:space:]]*red:|#colorLiteral' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```
Output: none (zero hits, exit 1).

```powershell
git grep -n -E '(Color|UIColor)[[:space:]]*\([[:space:]]*hex:|init[[:space:]]*\([[:space:]]*hex:|0x[0-9A-Fa-f]+|#[0-9A-Fa-f]{6,8}' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```
Output: none (zero hits, exit 1).

### Round 3 scope evidence

Exact command: `git diff --stat main`. Output captured before appending this report:

```text
 NearMe/App/AppCoordinator.swift                    |   7 +-
 NearMe/App/ContentView.swift                       |  12 +-
 NearMe/Views/Components/CaptionBubble.swift        |  60 ----
 NearMe/Views/Components/PrimaryButton.swift        |  54 ++--
 NearMe/Views/Components/ProgressDotsView.swift     |  33 +-
 NearMe/Views/Components/ScreenScaffold.swift       |  16 +-
 NearMe/Views/Components/SessionDock.swift          |   6 +-
 NearMe/Views/Components/Theme.swift                |  36 ++-
 NearMe/Views/Components/UIPolishPreviews.swift     | 353 +++++++++++++++++++++
 NearMe/Views/Components/VoiceOrbView.swift         | 140 ++++----
 NearMe/Views/Onboarding/GoodMorningView.swift      |  64 ----
 NearMe/Views/Onboarding/HowItWorksView.swift        |  61 ++--
 NearMe/Views/Onboarding/WelcomeView.swift          |  90 +++---
 .../TripPlannerPractice/TripPlannerChrome.swift    |  10 +-
 NearMe/Views/Voice/CoachPresentation.swift         |  39 +++
 NearMe/Views/Voice/CoachView.swift                 | 189 ++++++-----
 NearMe/Views/Voice/HelpHomeView.swift              | 212 +++++++++++++
 NearMe/Views/Voice/OpeningPracticeView.swift       |  19 +-
 NearMe/Views/Voice/SessionContainerView.swift      |   8 +-
 NearMe/Views/Voice/VoiceSessionView.swift          | 263 +++++----------
 NearMeTests/UIPolishTests.swift                    | 246 ++++++++++++++
 docs/LOG.md                                        |   4 -
 docs/PLAN.md                                       |   6 +-
 tasks/P07d-router-keyword-override.md              |  44 ---
 tasks/P09-ui-polish.md                             | 235 +++++++++++++-
 25 files changed, 1507 insertions(+), 700 deletions(-)
```

The main comparison includes prior lane commits and pre-existing branch divergence. This round's protected-path HEAD comparison is empty; its changes are limited to the five files listed above.

- Commit disposition: staging succeeded on `task/P09-ui-polish`; committing these five files as `N09: Preserve coach sessions through UI error recovery`. No merge or push.

- 2026-10-24 18:47 AEDT | P09 | codex | dev-report r3 | final review 1-4: preserve coach on errors and fallback rewrites, remove read-only preview override, restrict Cancel to active capture/preparation; Mac gate pending

## Review (round 3)
PASS (static; no Swift toolchain here). 1: `showsCoachCard` depends only on the session kind, so a guide or real general session keeps its card and dock error; Home's Try again and Type instead cancel only a `.homeReply` session, so the P07 progress store survives. 2: kind decided from `guide` and `generalSteps` only. 3: read-only `accessibilityReduceMotion` preview removed. 4: Cancel only while listening or preparing (preparing covers starting to listen, thinking and finishing). Tests replaced: guide plus error and real general plus error keep the card; no coach plus error and fallback plus error give the Home reply. Scope: no changes under Services, Models, ViewModels, Shared, project.yml or Info.plist on the whole branch.

PENDING MAC: everything in Verify (Mac), plus: no-words during a guide step keeps the coach card and its step; I'm stuck without the model keeps the card; new Stop on Home does not change cancel or barge-in; dock mic symbol readable with its state text; Open WhatsApp button opens WhatsApp without changing the step.
Follow-up for the manager: resuming a held fallback session after backgrounding says "You were on step 1: I'm not sure about that one" (engine, after P11).
- 2026-10-24 18:49 AEDT | P09 | claude (P09 lane) | review r3 PASS | coach card kept through errors, fallback from session kind only, preview compile fix, Cancel only while listening or preparing; rebased on origin/main, pushed, not merged

## Review (manager, merge round)
- Date: 2026-10-24 19:03 AEDT
- Branch: task/P09-merged = the lane's task/P09-ui-polish (5574517) merged with main (P07d, P11); conflicts resolved by the manager (AppCoordinator keeps P09's placeholderName and P11's init, pendingCoachURL, handleOpenURL; SessionContainerView.sessionContent: P11's isHome first, then P09's coach-card condition, practice, opening, P09 Home). Owner: do not merge to main until the combined iPhone check is reported.
- Scope guard met; P04b, Type instead, P03a, P07 coach, P07b dock, P07c intact.

Fixes (this round):
1. `NearMeTests/UIPolishTests.swift:104`: use `AppCoordinator(guides: [])` (main's AppCoordinator restores saved coach progress). If `Color(uiColor:)` equality at :15-18 is not stable, compare resolved components or drop it.
2. Home hint text exactly: "Try: 'Help me send a photo to Mum on WhatsApp'" (`HelpHomeView.swift:164`).
3. `VoiceOrbView.swift:13`: the dock's listening symbol back to `waveform` (P07b behaviour); Home's own button may keep its symbol choice.
4. Cancel: when not on Home and there is no step reply (`!engine.isHome && reply == nil`), for example waiting for "Where from?" or showing "Did you mean", show a bordered "Cancel" that calls the existing cancel action. Keep "End session" after a completed journey.
5. Home Stop only while NearMe is actually speaking (`activity == .speaking`), never during `isPreparingSpeech` or the P07d acknowledgement's preparation, so a request is not silently dropped.
6. Voice Control: add "Use voice" to the Talk button's `accessibilityInputLabels`.
7. Type-checker safety: move `showsCancel`, the button title and label choices in `HelpHomeView.swift:43-68` and the ternaries in `VoiceOrbView.swift:55-63` into small computed properties.
8. Open app row in the coach card only on step 1 (`CoachView.swift:94`).
9. Owner: big per-step icon on the coach card. In `CoachStepContent` between the progress block and the instruction text: `CoachStepPresentation.icon` from `session.guide?.steps[session.stepIndex].icon` (field from P07d); `Image(systemName:)`, `@ScaledMetric` about 60 pt, capped (smaller) at accessibility sizes, `.symbolRenderingMode(.hierarchical)`, accent colour, `.accessibilityHidden(true)`; skip when nil or `UIImage(systemName:)` is nil; no symbol effects; it fades with the existing step transition. Not in the dock or the Live Activity.
10. Tests for 2, 4, 5 and 9 (icon present when the step has one, absent otherwise).

## Dev Report (merge round)
- Date: 2026-10-24 19:05 AEDT
- Changed files: `NearMe/Views/Voice/HelpHomeView.swift`, `NearMe/Views/Components/VoiceOrbView.swift`, `NearMe/Views/Voice/CoachView.swift`, `NearMe/Views/Voice/CoachPresentation.swift`, `NearMe/Views/Components/UIPolishPreviews.swift`, `NearMeTests/UIPolishTests.swift`, this task file.
- What I did: addressed the ten manager merge-review items on `task/P09-merged`. Changes are limited to presentation, preview fixtures and tests. Preserved the manager's AppCoordinator and SessionContainerView conflict resolutions, P07d routing/acknowledgement and P11 progress/deep-link/Live Activity behavior. No engine, model, service, guide JSON, project or protected-document edits. The optional icon field is read from the existing model only.
- Acceptance criteria / Review (manager, merge round):
  1. Both onboarding test constructions now use `AppCoordinator(guides: [])`, so a previously saved guide cannot select the session route. Removed the four dynamic UIKit-backed Color equality assertions to avoid relying on provider equality; retained dimension, primary/secondary text and font assertions. Actual semantic appearance still needs the Mac visual gate.
  2. Home renders `HelpHomePresentation.hint` exactly as `Try: 'Help me send a photo to Mum on WhatsApp'`, with an exact-string regression assertion.
  3. `VoiceOrbState.listening.symbolName` is `waveform` again for the dock; the Home button retains its waveform. Existing Start/Stop listening VoiceOver labels and tap callbacks are unchanged.
  4. The read-only `HelpHomePresentation.showsCancel` keeps Cancel during capture/preparation and also when `!isHome && reply == nil`, including waiting journey prompts and place suggestions. The bordered Cancel still invokes the existing `cancel()` / `engine.cancelCurrentAction()` path. End session retains its completed-journey condition and existing callback.
  5. Stop is gated only by `activity == .speaking`. Preparation, including a speaking planner state during the P07d acknowledgement's preparation, does not expose Stop. The existing Stop command is unchanged.
  6. Talk and Try again include `Use voice` alongside their visible title and `Start listening` in Voice Control input labels. The listening action retains its visible instruction and `Stop listening` labels.
  7. Moved Home action visibility, Talk title/emphasis and Send emphasis into small computed properties. VoiceOrbButton resolves its title, symbol and input labels outside the view builder. No new app/test constructions or MainActor-static reads in default arguments, optional initializer dependencies, tuple chains or force unwraps were introduced.
  8. The view-only app-launch presentation helper now returns a link only at `stepIndex == 0`. General guidance and guides without a launch URL remain hidden. The engine's existing auto-open behavior is untouched. Tests cover first-step visibility and every later WhatsApp step being hidden.
  9. `CoachStepPresentation.icon` safely reads the current guide step's optional icon and rejects unavailable SF Symbols with `UIImage(systemName:)`. The card renders it between progress and instruction, with hierarchical rendering, the accent, and accessibilityHidden. A 60 pt ScaledMetric is capped at 72 pt for standard text and 44 pt for accessibility text sizes. No symbol effects; it participates in the existing step fade and Reduce Motion handling. No icon was added to the dock or Live Activity. Guide previews now include a first-step icon and Open app; general previews remain icon-free.
  10. Added regression coverage for exact hint copy, waiting prompts, Cancel on Home/replies, retained End session, Stop only during playback and hidden during acknowledgement preparation, and icon selection/absence. Icon tests cover changing steps, nil, an unknown name, an empty name, invalid indices and general guidance. Additional assertions cover waveform, Voice Control labels and first-step-only launch. The suite now contains 29 test methods (source count only).
- Verify commands run and results:
  - `git diff --check`: no output, exit 0.
  - `git diff --name-only HEAD -- NearMe/Services NearMe/Models NearMe/ViewModels Shared NearMeLiveActivity project.yml NearMe/Info.plist NearMe/Resources NearMe/Views/TripPlannerPractice NearMe/App NearMe/Views/Voice/SessionContainerView.swift docs/PLAN.md docs/LOG.md docs/SPEC.md AGENTS.md`: no output, exit 0. Protected files and both conflict resolutions are unchanged in this round.
  - `(Select-String -Path NearMeTests/UIPolishTests.swift -Pattern '    func test').Count`: `29`. `(Select-String -Path NearMe/Views/Components/UIPolishPreviews.swift -Pattern '^#Preview').Count`: `44`. Counts are not test or preview execution.
  - `Get-Command swift,xcodebuild -ErrorAction SilentlyContinue`: no output, exit 1. This Windows machine has no Swift or Xcode. No Swift build, XCTest run, preview rendering or iPhone verification was performed. `rg` was unavailable; used git grep and PowerShell.
  - Reviewed the full six-file code diff and the merged coordinator/session routing. Colour and scope commands/output are below.
- Mac test steps for the owner:
  1. On the Mac, use the `task/P09-merged` checkout containing these changes. Run `git branch --show-current` and confirm `task/P09-merged`, then `bash scripts/mac-run.sh test --current` and `bash scripts/mac-run.sh quick`. Require all default-run tests, including the 29 UIPolishTests and existing P07d/P11 tests, to pass. Inspect `build/xcodebuild.log` on failure. Do not merge to main before the combined iPhone check is reported.
  2. Open `NearMe.xcodeproj` in Xcode and render the 44 previews in `NearMe/Views/Components/UIPolishPreviews.swift`. Inspect Home, waiting conversation, fallback, guide coach, general coach and onboarding at default/accessibility5 in light/dark. The guide preview must show its icon and first-step Open WhatsApp; general guidance must have no icon. Confirm complete wrapping/scrolling and the smaller decorative icon at accessibility5.
  3. On an iOS 26.5 iPhone, confirm the exact Home example. Tap Talk, check the in-place waveform/live transcript, then Cancel and confirm nothing is submitted. Start a train request, wait for Where from and exercise an ambiguous place response that displays Did you mean: bordered Cancel must remain available after speech finishes and return Home. Complete a practice journey and confirm End session still appears and works.
  4. With the P07d acknowledgement enabled, ask for WhatsApp help and observe preparation before playback: Stop must be absent until the activity says Speaking, and the request must continue into its guide. During actual playback, Stop must interrupt speech; then test Talk barge-in. Turn on Voice Control and say Use voice from both Talk and Try again. With VoiceOver, verify Start listening/Stop listening labels and confirm the decorative coach icon is skipped.
  5. Follow the WhatsApp guide: Open WhatsApp must appear on step 1, open the app without advancing, and disappear after Done advances to step 2. Confirm each supplied step icon updates with the instruction and uses only the existing fade. Check a guide step with no icon and general guidance: no placeholder or blank symbol. Enable Reduce Motion, Reduce Transparency, Bold Text and Button Shapes, then repeat at Accessibility XXXL in light/dark.
  6. At WhatsApp step 3, submit a no-words turn and an unrecognised command: the coach/dock error must remain at step 3. Retry and use Type instead without losing progress. Exercise I'm stuck for real general guidance with the model unavailable: the card and sheet must remain. Background/foreground and relaunch with saved progress; test existing P11 Live Activity Open/Done deep links and confirm correct restoration/advance behavior. Check the dock still uses waveform while listening and no large step icon appears in the dock or Live Activity.
- Not done / risks / questions: all ten fixes are implemented statically; Swift 6.4 compilation, runtime tests, symbol rendering, accessibility layout and the combined P07d/P11 iPhone check remain PENDING MAC. No merge, push or next task. `docs/PLAN.md` and `docs/LOG.md` were not edited, per the user's instruction.
- Commit disposition: **UNCOMMITTED; manager must commit.** Staging succeeded and `git diff --cached --check` passed, but `git commit -m "P09: Address merge review and add coach step icons"` failed (exit 1): `fatal: Unable to create 'C:/Users/User/Desktop/projects/NearMe/.git/worktrees/NearMe-p09trial/index.lock': Permission denied`. The sandbox cannot write the required Git metadata. Per the user's instruction, no retry or permission escalation was attempted. The code and initial report are staged; this final report correction is unstaged. The manager should stage the updated task file and commit the seven files with the intended `P09:` message. No merge or push; stopped after recording the failure.

### Merge-round colour evidence

```powershell
git grep -n -E 'Color[[:space:]]*\([[:space:]]*red:|#colorLiteral' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```
Output: none (zero hits, exit 1).

```powershell
git grep -n -E '(Color|UIColor)[[:space:]]*\([[:space:]]*hex:|init[[:space:]]*\([[:space:]]*hex:|0x[0-9A-Fa-f]+|#[0-9A-Fa-f]{6,8}' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```
Output: none (zero hits, exit 1).

```powershell
git grep -n -E '\.purple|\.black|\.tracking\(|\.kerning\(|\.uppercased\(' -- NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'
```
Output: none (zero hits, exit 1).

### Merge-round scope evidence

Exact command: `git diff --stat main`. Output captured before appending this report:

```text
 NearMe/App/AppCoordinator.swift                    |   7 +-
 NearMe/App/ContentView.swift                       |  12 +-
 NearMe/Views/Components/CaptionBubble.swift        |  60 ----
 NearMe/Views/Components/PrimaryButton.swift        |  54 ++--
 NearMe/Views/Components/ProgressDotsView.swift     |  33 +-
 NearMe/Views/Components/ScreenScaffold.swift       |  16 +-
 NearMe/Views/Components/SessionDock.swift          |   6 +-
 NearMe/Views/Components/Theme.swift                |  36 ++-
 NearMe/Views/Components/UIPolishPreviews.swift     | 357 +++++++++++++++++++++
 NearMe/Views/Components/VoiceOrbView.swift         | 152 +++++----
 NearMe/Views/Onboarding/GoodMorningView.swift      |  64 ----
 NearMe/Views/Onboarding/HowItWorksView.swift       |  61 ++--
 NearMe/Views/Onboarding/WelcomeView.swift          |  90 +++---
 .../TripPlannerPractice/TripPlannerChrome.swift    |  10 +-
 NearMe/Views/Voice/CoachPresentation.swift         |  40 +++
 NearMe/Views/Voice/CoachView.swift                 | 215 ++++++++-----
 NearMe/Views/Voice/HelpHomeView.swift              | 249 ++++++++++++++
 NearMe/Views/Voice/OpeningPracticeView.swift       |  19 +-
 NearMe/Views/Voice/SessionContainerView.swift      |   5 +-
 NearMe/Views/Voice/VoiceSessionView.swift          | 263 +++++----------
 NearMeTests/UIPolishTests.swift                    | 352 ++++++++++++++++++++
 tasks/P09-ui-polish.md                             | 336 ++++++++++++++++++-
 22 files changed, 1795 insertions(+), 642 deletions(-)
```

This comparison includes the prior P09 lane. The merge-round HEAD comparison changes only the seven files listed in this report; the protected-path comparison is empty.

## Owner revision (replaces the Home redesign) - 2026-10-24 19:40 AEDT
Branch task/P09-merged now also includes main up to ce0e619 (P07e, P13 spike, P12 revert); conflicts in CoachView.swift and VoiceSessionView.swift resolved to P09's structure. P13b merges to main before this branch. No behaviour changes beyond navigation.

1. Remove the "What do you need help with?" home page entirely (HelpHomeView as a separate page). After onboarding "start" and on every later app launch, go straight to the orb voice screen (the purple listening screen); that screen IS home. Deep links (nearme://coach) and the coach, practice and opening screens keep working as today.
2. Idle state of that screen: the orb, one line "Tap and tell me what you need help with", and a small hint "Try: 'Help me play a song on YouTube'". Listening state: the orb animates and ONE label "Listening... tap when you're done". Remove the duplicate "LISTENING...." caption and any second "Listening..." line.
3. Secondary actions live in a "More" menu at the top right (SF Symbol ellipsis.circle, label "More", 44 x 44 pt): "Let NearMe see my screen" (opens the existing broadcast picker sheet from the P13 spike), "Practice mode", "Type instead", "Settings" (a simple sheet; it can hold the existing toggles or "Coming soon" for anything not built), "Show debug info" (DEBUG builds only). Keep "Type instead" also as one quiet text button under the orb. During a coach guide the dock's More menu also has "Let NearMe see my screen".
4. "Cancel" appears only while listening; when idle there is no bottom button.
5. Purple theme everywhere, from docs/ui-mockups/purple-v2/AGENT-HANDOFF.md (read-only): plum #291B43, violet #6E45BC, lavender #D9C8F2, pale lavender #F0EAF8, as named Theme tokens with accessible Dark Mode variants (text on violet meets 4.5:1). Set the app's accent (AccentColor asset and the SwiftUI tint) to violet so no default blue remains, including the More menu, Type instead, toggles, links and system pickers. Reading surfaces stay semantic system backgrounds.
6. Keep P07e behaviour: an empty typed answer to "Which song would you like to play?" is allowed (isAwaitingSong), wherever typing lives.
7. Tests: launch goes to the orb screen (no separate home page); idle shows the one line and hint and no bottom button; listening shows exactly one listening label and Cancel; More menu items present (debug item only in DEBUG); accent is violet.
Swift 6.4 rules: default arguments must not construct NearMe or test types or read MainActor statics; split long chains over tuples into typed steps; keep SwiftUI bodies small; use resolved stored properties, not optional init parameters.


## Dev Report (owner revision)
- Date: 2026-10-24 19:44 AEDT
- Changed files: `NearMe/App/ContentView.swift`; `NearMe/Assets.xcassets/AccentColor.colorset/Contents.json` and new `Plum`, `Lavender`, `PaleLavender`, `OnAccent` color sets; Components: `Theme.swift`, `PrimaryButton.swift`, `VoiceOrbView.swift`, `VoiceSessionMenu.swift` (new), `ScreenBroadcastButton.swift`, `SessionDock.swift`, `UIPolishPreviews.swift`; Voice: `VoiceSessionView.swift`, `VoiceHomeContent.swift` (new), `SessionContainerView.swift`, deleted `HelpHomeView.swift`; `NearMeTests/UIPolishTests.swift`; this task file.
- What I did: implemented only owner revision items 1-7 on `task/P09-merged`. The orb is now Home and the conversation surface. Kept existing speech, routing commands, guide content, coach actions, practice and opening screens. Secondary entry points use the More menu. No Services, Models, ViewModels, guide JSON, extensions, Shared, project settings, coordinator, PLAN, LOG or mockup edits. The palette handoff file was absent; used the four exact colors in the owner brief.
- Acceptance criteria:
  1. Removed the separate `HelpHomeView` file/page. `SessionContainerView` selects `VoiceSessionView` for Home and non-step conversations, with the same precedence for coach/practice/opening. `ContentView` stores onboarding completion with `@AppStorage` and resolves subsequent launches directly to the session. Ordinary launch no longer calls `restoreCoach()` in the container, so saved progress does not redirect launch away from the orb. Saved progress is not cleared: explicit coach URLs still invoke the unchanged `engine.openCoachURL`, and active coach background/foreground resume still invokes the existing lifecycle commands. No coordinator/engine changes.
  2. Idle renders the orb, exactly `Tap and tell me what you need help with`, and `Try: 'Help me play a song on YouTube'`. Listening uses one status Text, `Listening... tap when you're done`, no hint and no second state row. Only the decorative orb halo animates during capture; Reduce Motion makes it static. Original Start listening/Stop listening and Use voice accessibility commands remain. Content scrolls and the orb shrinks at accessibility sizes; transcripts remain opaque semantic reading cards.
  3. Added the top-right ellipsis.circle More control with a 44 x 44 pt frame and More accessibility label. Its items are Let NearMe see my screen, Practice mode, Type instead, Settings, plus Show debug info compiled only under DEBUG. Type instead is also a quiet button under the orb. Home uses a single sheet destination for broadcast or Settings; Settings truthfully says more settings are coming soon. The coach/practice dock More menu presents the same existing broadcast picker sheet. Completed journeys retain End session in More. Broadcast changes are UI-only: made the existing sheet reusable and applied tint; no capture/service/extension behavior changed.
  4. Cancel is visible only for `.listening` and retains the existing cancellation command. No idle bottom action, including while waiting for a journey reply or after a completed journey. Stop remains available only during actual playback; typed Send remains in the explicit typing UI.
  5. Named Theme tokens use appearance-aware color assets. Light: plum #291B43, violet/AccentColor #6E45BC, lavender #D9C8F2, pale lavender #F0EAF8. Dark: plum text #E9DEF7, violet #BFA0ED, lavender #493064, pale lavender #1D152C. `OnAccent` is white in Light Mode and #291B43 in Dark Mode. Both prominent button labels and the orb symbol use OnAccent. Root SwiftUI tint, component tints and the embedded UIKit broadcast picker use violet; the app AccentColor asset is populated. Reading backgrounds remain system semantic colors. Calculated sRGB contrast: OnAccent/violet 6.48:1 light, 7.11:1 dark; plum/pale lavender 13.38:1 light, 13.59:1 dark; violet text/pale lavender 5.50:1 light, 7.92:1 dark. Actual system picker rendering remains a device check.
  6. Both voice-screen and dock typing call `TypedAnswerPresentation.canSend`, which permits empty/whitespace text only when `isAwaitingSong` and `canSubmitTypedInput` are true. Submission still calls the existing engine method. No song routing or engine changes.
  7. Replaced superseded Home/cancel assertions and added checks for onboarding/launch destination, retained coach/practice/opening precedence, exact idle/listening text and hint visibility, Cancel only while listening, DEBUG/release menu membership, blank-song gating, named violet accent components and light/dark contrast. The suite now has 33 XCTest methods. Updated the existing 44 preview variants to render the orb layout and More menu. These are source counts, not executed tests/previews. SwiftUI content is split into small views/computed properties; no new force unwraps, type-constructing default arguments, MainActor-static default arguments or long tuple chains.
- Verify commands run and results:
  - `git diff --check`: final exit 0, no whitespace errors. An initial extra blank line at EOF was fixed. Git emitted only an AccentColor line-ending conversion warning.
  - `git diff --name-only HEAD -- NearMe/Services NearMe/Models NearMe/ViewModels Shared NearMeLiveActivity NearMeBroadcastExtension project.yml NearMe/Info.plist NearMe/Resources NearMe/Views/TripPlannerPractice NearMe/App/AppCoordinator.swift NearMe/App/NearMeApp.swift docs/PLAN.md docs/LOG.md docs/SPEC.md docs/ui-mockups AGENTS.md`: empty output, exit 0. These protected paths are unchanged in this revision.
  - `git grep -n -E 'systemBlue|\.blue|\.tracking\(|\.kerning\(|\.uppercased\(' -- NearMe/App NearMe/Views ':!NearMe/Views/TripPlannerPractice/**'`: no matches, exit 1. The imitation practice app retains its existing look.
  - Inline Python inspection of the five color-set JSON files: all six foreground/background contrast checks above passed the 4.5:1 threshold.
  - Inline Python source assertions: PASS for one orb status Text and no second VoiceStateRow; old Home file/type removed; explicit coach URL call retained; no automatic restore on ordinary launch; both typing surfaces use the song exception; both present the existing broadcast sheet. Stripping DEBUG blocks from the menu source leaves the four required items and no debug item. A first source scan hit the Windows default-codepage decoder; the scan was rerun with explicit UTF-8 and passed. These are static checks, not Swift execution.
  - `git diff --stat main` inspected: it includes earlier P09 commits and existing PLAN/LOG branch divergence, not changes made to those files in this revision. New untracked assets/views are separately listed by `git ls-files --others --exclude-standard` until staging.
  - `Get-Command swift,xcodebuild -ErrorAction SilentlyContinue`: no commands found. This Windows machine has no Swift or Xcode. No Swift 6.4 build, XCTest, preview rendering or device test was run. `rg --version` was unavailable at execution; used git grep and explicit UTF-8 file scans.
- Mac test steps for the owner:
  1. In the checkout containing this revision, run `git branch --show-current` and confirm `task/P09-merged`. Run `bash scripts/mac-run.sh test --current`, then `bash scripts/mac-run.sh quick`. Require the full default test suite, including all 33 UIPolishTests and P07e/P11 tests, to pass. Inspect `build/xcodebuild.log` on any failure. The script regenerates XcodeGen for the added/deleted files and assets; do not commit NearMe.xcodeproj.
  2. Check the release-only branch as well: run `sim_id="$(xcrun simctl list devices booted -j | python3 scripts/newest-iphone.py --booted)"`, then `xcodebuild -scheme NearMe -configuration Release -destination "id=$sim_id" -derivedDataPath build-release CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES test -only-testing:NearMeTests/UIPolishTests`. Confirm the menu-membership test passes without DEBUG. Install with `xcrun simctl install "$sim_id" build-release/Build/Products/Release-iphonesimulator/NearMe.app`, terminate any running NearMe instance, and launch with `xcrun simctl launch "$sim_id" au.nearme.ios`; More must omit Show debug info.
  3. Use a clean test simulator installation for the first-run check. Complete Welcome and Try it now (repeat with Skip on another clean run): arrive directly at the orb. Idle must show the exact instruction and YouTube hint, quiet Type instead, More and no Cancel/Stop/End-session bottom button. Force-quit/relaunch: orb immediately, no onboarding or separate Home page. Start a guide, force-quit/relaunch with saved progress: still orb. Use the guide's Live Activity/Open deep link and confirm that the saved guide and step restore. Background/foreground an active guide and confirm existing resume still works. Test a Home/stale link as well.
  4. Tap the orb, grant permissions if needed, and confirm one listening label, an animated halo and Cancel. Tap again to finish; Cancel must disappear during preparation. Cancel during capture must stop without submitting. Check a no-words reply, a fallback reply, Where from and Did you mean: replies remain readable and no idle Cancel appears. Confirm Stop only during playback and Talk still interrupts speech. Complete a practice journey and use More > End session.
  5. Exercise every Home More item and the quiet Type instead button. Settings opens/dismisses; DEBUG toggles the existing diagnostics. Start a guide and open dock More > Let NearMe see my screen. On a physical iPhone, verify both entry points open the existing broadcast sheet, its picker starts the existing broadcast and can be stopped using the system recording control; follow the P13/P13b device gate after integration. No new claim about screen understanding was added here.
  6. Ask for help playing a song on YouTube. At Which song would you like to play, choose Type instead from More and submit an empty answer, then repeat with whitespace using the quiet Type instead control: the existing P07e default-song behavior must continue. Confirm empty ordinary answers stay disabled and nonempty song input works. Exercise typed coach/practice dock input too.
  7. Open NearMe.xcodeproj and render the 44 UIPolishPreviews variants at default and accessibility5 in light/dark. Verify no clipped controls or text, one listening label and smaller orb at accessibility sizes. Check onboarding, guide icon/Open app, coach help, captions, Settings, More menus, typing, links, toggles and broadcast sheet: violet tint with opaque semantic reading cards. Verify primary-button foreground contrast in the rendered app, especially Dark Mode.
  8. On iPhone enable Reduce Motion, Reduce Transparency, Bold Text and Button Shapes; repeat idle/listening, coach and menus at Accessibility XXXL. The halo must stop animating with Reduce Motion. With VoiceOver check Start listening/Stop listening, state text, More and menu actions; with Voice Control say Use voice. Test coach Done/Repeat/I'm stuck/Open app, practice and opening transitions, and P11 Live Activity Open/Done after the parallel P13b merge. Do not merge before the combined Mac/iPhone gate.
- Not done / risks / questions: runtime validation remains PENDING MAC. The owner-requested relaunch behavior intentionally replaces automatic saved-coach restoration with the orb; explicit coach URLs and current-session resume are preserved. Existing installs without the new onboarding-completion preference and without saved progress will see onboarding once before future launches go straight to the orb. P13b may touch the broadcast UI file: retain its capture changes when merging, along with this revision's reusable sheet access and tint. No merge, push or next task. No changes to docs/PLAN.md, docs/LOG.md or docs/ui-mockups/.
- Intended commit: `P09: Restore orb home and apply purple UI revision`. Commit disposition is recorded below after the requested Git write attempt.

- Commit disposition: **UNCOMMITTED; manager must commit.** Explicit staging of the 19 revision paths succeeded; `git diff --cached --check` reported no whitespace errors. `git commit -m "P09: Restore orb home and apply purple UI revision"` failed (exit 1): `fatal: Unable to create 'C:/Users/User/Desktop/projects/NearMe/.git/worktrees/NearMe-p09trial/index.lock': Permission denied`. The sandbox cannot write the required Git metadata. Per the owner's instruction, no retry or escalation was attempted. The implementation, assets, tests and initial report are staged; this disposition append is unstaged. The manager should stage the updated task file and commit with the intended P09 message. No merge or push; stopped after recording this failure.
