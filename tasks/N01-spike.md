# N01: Spike: read buttons, model picks one, draw ring (kill-rule test)

| Field | Value |
|---|---|
| Status | changes_requested |
| Window | Sat 24 Oct 13:00 to 14:00 |
| Depends on | N00 |
| Assignee | codex, then owner on Mac |
| Branch | task/N01-spike |

## Goal
Prove the core loop on real System Settings within 60 minutes of having the Mac.

## Read
AGENTS.md; docs/SPEC.md

## Acceptance criteria
- [ ] `AXPermission`: checks AXIsProcessTrustedWithOptions and opens the Privacy pane if not trusted
- [ ] `AXReader` (app target): for the frontmost app, walk the focused window's AX tree (max depth 25, max 400 nodes, 300 ms budget), flatten actionable elements with role in {AXButton, AXCheckBox, AXRadioButton, AXPopUpButton, AXMenuItem, AXRow, AXCell, AXLink, AXTab, AXTextField, AXSlider, AXStaticText inside rows}, record title/description/value-free label, frame, enabled, parent label breadcrumb
- [ ] `ElementList` model in NearMeCore with stable indices and a compact text rendering for the prompt, capped at 120 items (prefer items in sidebar and main content)
- [ ] `StepPlanner` (app target) uses Foundation Models with a @Generable `PlannedStep { elementIndex: Int, action: Action(click, scroll, none), instruction: String, isGoalComplete: Bool, needsClarification: Bool }`, fresh session per step, no tools
- [ ] `StepValidator` in NearMeCore: index in range, element enabled, action allowed; else invalid
- [ ] `Overlay`: borderless, transparent, ignoresMouseEvents, level .screenSaver window drawing a rounded ring at the element frame; correct AX (top-left) to AppKit (bottom-left) conversion using the main screen height
- [ ] Debug panel: text field for goal, 'Next step' button, shows element count, chosen element, latency in ms
- [ ] Target app: NearMe tracks the last activated app that is not NearMe itself (NSWorkspace didActivateApplicationNotification) and AXReader reads that app, because clicking "Next step" makes NearMe frontmost. The debug panel shows the target app name and window title
- [ ] Cap rule (testable): when over 120 items, drop items with an empty label first, then keep the first 120 in traversal order. Indices are 0-based and contiguous after capping
- [ ] Prompt: goal, app name, window title and the numbered element list rendered by `ElementList`; instructions say to pick only an index from the list, and to set needsClarification when nothing fits
- [ ] AX top-left to AppKit bottom-left rect conversion is a pure function in NearMeCore (CoreGraphics/Foundation types only)
- [ ] Unit tests in NearMeCore for: ElementList rendering and cap rule, StepValidator (in range, out of range, negative, disabled element, disallowed action), rect conversion
- [ ] Debug panel also shows the chosen element's role and label, the instruction text, AX read ms and model ms separately, and a Clear ring button. If Foundation Models is unavailable or the model call throws, the panel shows the error and the app does not crash
- [ ] Overlay never takes focus or activates NearMe, and NearMe never performs AX actions (no AXPress, no setting values)
- [ ] Owner gate on Mac: goal 'make text bigger' with System Settings frontmost gives a sensible first step and the ring lands on it. Record result and latency in LOG

## Verify
```
swift test --package-path NearMeCore
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)
- Date: 2026-10-24 12:36 AEDT
- Changed files: NearMe/AXPermission.swift; NearMe/AXReader.swift; NearMe/TargetAppTracker.swift; NearMe/StepPlanner.swift; NearMe/Overlay.swift; NearMe/DebugViewModel.swift; NearMe/ContentView.swift; NearMe/NearMeApp.swift; NearMeCore/Sources/NearMeCore/ElementList.swift; NearMeCore/Sources/NearMeCore/StepValidator.swift; NearMeCore/Tests/NearMeCoreTests/GuidanceTests.swift; tasks/N01-spike.md.
- What I did: Replaced the scaffold status view with the manual N01 debug loop. The app remembers the last external app, reads a bounded, value-free AX snapshot off the main thread, asks a fresh tool-free Foundation Models session for one structured step, validates it, and draws a nonactivating ring. Clear ring cancels pending work; target changes discard stale results. No speech, AX observation/replanning, or later-task features were added.
- Acceptance criteria (implementation coverage; Mac runtime verification remains pending):
  1. AXPermission calls AXIsProcessTrustedWithOptions off the main thread. Its request path opens the Accessibility Privacy pane when untrusted; both Next step and the explicit settings button can invoke it.
  2. AXReader reads the chosen application's focused window with maximum depth 25, 400 traversal nodes, a 300 ms deadline/watchdog, and per-message AX timeouts bounded by the remaining budget. It includes the specified roles and static text only under rows, reads title/description without AXValue, and records frames, enabled state, and up to three ancestor labels. Secure text fields and descendants are skipped. AX references stay inside the detached worker.
  3. NearMeCore ElementList stores immutable snapshots, caps at 120, renders compact numbered lines, and uses array positions as stable indices for that snapshot. AX traversal prefers the focused window's content containers over toolbar/window controls, retaining native order within sidebar/main-content containers.
  4. StepPlanner defines @Generable PlannedStep and Action(click, scroll, none), checks model availability, creates a new LanguageModelSession for each step, and supplies no tools.
  5. StepValidator requires an existing nonnegative index, an enabled element, and one of click/scroll/none. Invalid selections never draw a ring.
  6. Overlay uses a transparent borderless NSPanel at .screenSaver, ignores mouse events, and draws a rounded orange ring. It converts AX coordinates with the primary/menu-bar screen height (NSScreen.screens.first), avoiding NSScreen.main's key-window-dependent choice.
  7. Debug panel includes goal, Next step, capped element count, chosen element, and total latency in milliseconds.
  8. TargetAppTracker observes NSWorkspace.didActivateApplicationNotification, ignores NearMe's own PID, and seeds from the current frontmost app. AXReader receives that remembered PID. The panel displays target app and focused window title.
  9. When input exceeds 120, ElementList removes empty/whitespace-only labels first, then takes the first 120 remaining items in traversal order. It does not remove empty labels at or below capacity. Rendered indices are contiguous and zero-based after capping.
  10. ElementList renders the goal, app name, window title, and numbered list. It requires choosing only a supplied index and needsClarification when nothing fits. UI strings are quoted, whitespace-normalized, escaped and length-limited; planner instructions treat them as data.
  11. ScreenCoordinates.appKitRect is a pure Foundation/CGRect function in NearMeCore, implementing y = mainScreenHeight - axRect.maxY.
  12. Added seven core test functions covering snapshot fields, exact rendering, empty/at-capacity/over-capacity lists, empty-first capping and reindexing, traversal order, prompt grounding/escaping/length, all requested validator cases, and coordinate conversion including negative coordinates. Existing scaffold test retained (eight test functions total). Tests have NOT run here.
  13. Panel shows role, label, instruction, AX read time, model time, total time, Clear ring, and readable availability/read/model errors. Exceptions are caught. Completion, clarification and action=none do not draw a ring.
  14. The panel uses .nonactivatingPanel, overrides canBecomeKey/canBecomeMain to false, and orders front without an activation call. Static scan found no AX action execution or attribute-setting API. Focus/click-through behavior must still be checked on Mac.
  15. OWNER GATE PENDING: no Mac was available to try System Settings / make text bigger, assess ring placement, or measure real latency. No successful kill-rule result is claimed; owner must record the observed result and latency in docs/LOG.md.
- Verify commands run and results:
  - `swift test --package-path NearMeCore`: could not execute; swift is not installed/recognized on this Windows machine.
  - `xcodegen`: could not execute; command is unavailable.
  - `xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`: could not execute; command is unavailable. The task's generation/build sequence was attempted as separate PowerShell commands because this shell does not support `&&`.
  - `git diff --check`: passed for tracked changes.
  - PowerShell source checks: passed for forbidden core imports, AX action/value-reading APIs, force unwraps/casts, trailing whitespace (including new Swift files), reader limit markers, and overlay nonactivation/click-through markers. These are static checks, not compilation or runtime tests.
  - `git status --short` and `git branch --show-current`: initial tree was clean, branch is task/N01-spike; changes remain within N01 files.
  - Consulted Apple's Foundation Models guided-generation and AX messaging-timeout documentation for the framework integration: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation and https://developer.apple.com/documentation/applicationservices/1459345-axuielementsetmessagingtimeout .
- Mac test steps for the owner:
  1. On Apple silicon with macOS 26, Xcode 26 and Apple Intelligence enabled/model downloaded, check out the manager's N01 commit. In the repository root run `swift test --package-path NearMeCore`; all eight test functions must pass.
  2. Run `xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`. Then open NearMe.xcodeproj, select the NearMe scheme and My Mac, and run from Xcode. Keep the generated project uncommitted.
  3. Click Open Accessibility Settings. If NearMe is not trusted, verify Privacy & Security > Accessibility opens, enable NearMe, and relaunch if macOS requests it. Return to NearMe and confirm Accessibility is Granted and Foundation Models is Available.
  4. Use one display for the kill-rule test. Place the NearMe panel and System Settings side by side so the target is not obscured. Open System Settings at its main page, activate it, then return to NearMe. Confirm Target app still says System Settings.
  5. Enter exactly `make text bigger` and click Next step. Confirm the window title belongs to System Settings, element count is nonzero and at most 120, and the chosen index/role/label plus instruction describe a sensible first step (for example Accessibility). Check that the ring surrounds the chosen real control. Record element count, chosen role/label, AX ms, model ms, total ms, correctness and ring alignment in docs/LOG.md, with the timestamp and attempt number. Mark the owner gate pass/fail from observations, within 60 minutes of first Mac access.
  6. Click the highlighted System Settings control yourself. Confirm the overlay does not consume the click or become key. Confirm no control is clicked automatically by NearMe. Return to NearMe, click Clear ring, and confirm the ring disappears. Click Next step then immediately Clear ring; no late result should restore it.
  7. Activate Finder, return to NearMe, and verify the target changes to Finder and old ring/results clear. Activate System Settings again and verify the target switches back. During a pending model request, activate a different app and confirm its predecessor's result is discarded.
  8. Try an unrelated/unavailable goal and confirm clarification or a caught error leaves no ring. On a Mac with Foundation Models unavailable, confirm the availability reason/error is visible and the app remains responsive. Revoke Accessibility and try Next step to verify the permission path. Record any errors or partial-read warning alongside the kill-rule result.
- Not done / risks / questions: This machine has no Swift or Xcode. GitHub CI remains the compile gate; neither Swift 6 compilation nor the new tests are verified here. The real System Settings AX labels, enabled attributes, 300 ms budget, content-container prioritization, model context capacity/accuracy, and ring focus/placement need Mac validation. Missing enabled attributes on actionable controls are treated conservatively as disabled; row static text can inherit an enabled parent. Labels exposed only through AXValue are deliberately unavailable. The 300 ms watchdog bounds the caller's wait subject to OS scheduling; synchronous AX IPC cannot be forcibly interrupted, but worker cancellation and per-message timeouts bound subsequent work. This spike does not observe same-app window changes during model inference; keep the target window still until a result, and use Clear ring/Next step after changes. No real kill-rule result or latency has been fabricated.

## Review (round 1)
- Date: 2026-10-24 12:40 AEDT
- Verdict: CHANGES
- CI run 40050658883 FAILED: NearMeCore does not compile (`CGRect` has no member minX/maxY/width/height; `ScreenElement` does not conform to Equatable; StepValidator.swift:14).

Fixes (address every one):
1. Compile: add `import CoreGraphics` to every NearMeCore source file and test file that uses CGRect/CGFloat (ElementList.swift, StepValidator.swift, GuidanceTests.swift). Keep Foundation. Then re-check every NearMeCore file and the app target for other compile errors you can spot by reading.
2. AXReader.swift:34-38 and :63-65: the 300 ms watchdog and the walk's own 300 ms deadline race, so a partial walk is often discarded as timed out. Make the walk stop at 250 ms measured from one shared start time, and keep the watchdog at 300 ms from that same start as a backstop only. A walk that hits its budget returns its partial ElementList (panel notes "truncated"), not an error.
3. AXReader.swift:139: a missing AXEnabled attribute must mean enabled (`?? true`). Only an explicit false marks an element disabled.
4. AXReader.swift:131-132, labels (manager decision, logged in PLAN.md): for AXStaticText only, use AXValue as its label, because that is its visible text. Never read AXValue for any other role (no text fields, secure fields, sliders, checkboxes). For AXRow and AXCell with an empty title and description, label them from their first AXStaticText descendant (max 3 levels down, same budget).
5. Breadcrumb: keep only the nearest labelled ancestor (one level) to keep the prompt well under the on-device context limit.
6. Remove every em dash character (U+2014) from code and UI strings (DebugViewModel.swift:13, :15, :139; ContentView.swift:23, :66). Use "-" for blank values.
7. Add unit tests if any NearMeCore behaviour changes. Nits, optional: drop `isFloatingPanel`; don't set `truncated` on cancellation.
