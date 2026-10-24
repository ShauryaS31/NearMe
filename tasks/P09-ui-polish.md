# P09: UI polish (native look, calm and readable)

| Field | Value |
|---|---|
| Status | in_progress (P09 lane worker, worktree ../NearMe-p09) |
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
