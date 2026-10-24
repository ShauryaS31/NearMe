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

## Dev Report (round 2)
- Date: 2026-10-24 12:41 AEDT
- Changed files: NearMe/AXReader.swift; NearMe/ContentView.swift; NearMe/DebugViewModel.swift; NearMe/Overlay.swift; NearMeCore/Sources/NearMeCore/ElementList.swift; NearMeCore/Sources/NearMeCore/StepValidator.swift; NearMeCore/Tests/NearMeCoreTests/GuidanceTests.swift; tasks/N01-spike.md. docs/LOG.md is to be appended after a successful commit, per the requested order.
- What I did (Review round 1, every numbered fix):
  1. Kept Foundation and added CoreGraphics to ElementList.swift, StepValidator.swift and GuidanceTests.swift. Read all 14 Swift files, including the package manifest and both targets, for additional compile problems; none further identified by inspection. Compilation is still unverified.
  2. Captured one ContinuousClock start before launching either detached task. The traversal uses a 250 ms deadline from that start; the watchdog sleeps until start + 300 ms. Budget exhaustion returns the accumulated snapshot with wasTruncated, including an empty snapshot if the budget expires before a window is available. The debug panel explicitly displays "truncated read". The watchdog remains a backstop for a worker that does not return.
  3. AXEnabled now defaults to true when absent. Only an explicit false on the element disables it; removed the previous missing-attribute and inherited-state restrictions.
  4. AXStaticText labels come from AXValue. The sole kAXValueAttribute read is guarded by that role; no other role's value is queried. Empty-title/description AXRow and AXCell labels use their first static-text descendant in native depth-first order, at most three levels down. Lookup shares the 250 ms deadline, per-message timeout, 400 visit budget and overall depth-25 bound. Both traversal and label lookup skip secure controls and their descendants.
  5. Replaced the three-label ancestor chain with one nearest labelled ancestor. Unlabelled intermediate containers preserve that nearest label.
  6. Replaced every U+2014 in Swift source/UI strings with ASCII hyphens, including blank values, target guidance and chosen-element text.
  7. NearMeCore behavior did not change: only imports and the snapshot documentation changed. Existing rendering/capping, validator and coordinate tests remain applicable; no new core behavior requires tests. Removed isFloatingPanel and separated cancellation exits from truncation conditions, including AX cannotComplete handling.
- Acceptance criteria (implementation coverage, not a claim of runtime success):
  1. AXPermission still checks AXIsProcessTrustedWithOptions and opens the Accessibility Privacy pane when needed; unchanged.
  2. AXReader still walks the remembered target's focused window off the main thread, keeps the specified roles/frames, and bounds depth and visits. The reviewed 250/300 ms deadlines, static-text-only value exception, row/cell labels, enabled default and nearest-ancestor breadcrumb are implemented above.
  3. ElementList retains its 120-item cap, compact rendering and snapshot indices. Window content-container preference remains in AXReader.
  4. StepPlanner retains fresh tool-free Foundation Models sessions and the specified @Generable step/action types; unchanged.
  5. StepValidator still rejects absent/negative indices, disabled elements and unsupported actions; CoreGraphics import fixes its geometry dependency.
  6. Overlay retains a borderless transparent click-through .screenSaver panel and primary-screen AX-to-AppKit conversion; removed only the redundant floating-panel setting.
  7. Goal entry, Next step, element count, chosen element and total latency remain available; blank values now use "-".
  8. Last external app tracking, target app display and window title display remain unchanged.
  9. Empty-label-first capping, traversal order and contiguous zero-based indices remain unchanged and covered by existing tests.
  10. Prompt still contains goal/app/window and ElementList rendering with list-only selection and clarification instructions. Reader breadcrumbs now contain a single ancestor label.
  11. ScreenCoordinates.appKitRect remains a pure core function; both Foundation and CoreGraphics are imported explicitly.
  12. All eight existing core test functions are retained, with the missing CoreGraphics test import added. They could not run on this machine.
  13. Role/label/instruction, separate AX/model timings, Clear ring and caught model errors remain. Partial snapshots now show an explicit truncated-read notice.
  14. Overlay still cannot become key/main and ignores mouse events; static scan found no AX action execution or attribute-setting APIs.
  15. Owner gate remains pending: no Mac/System Settings result or measured model latency is claimed.
- Verify commands run and results:
  - `swift test --package-path NearMeCore`: could not execute; swift is not installed/recognized.
  - `xcodegen`: could not execute; command is unavailable.
  - `xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`: could not execute; command is unavailable. Generation and build were attempted separately in PowerShell.
  - `git diff --check`: passed after the code changes.
  - PowerShell static source assertions across all 14 Swift files: passed for required core geometry imports, absence of forbidden core framework imports, absence of U+2014 and AX action APIs, force-operation scan, the single role-guarded AXValue read, shared-start/deadline markers, lookup depth/node bounds, enabled default, single breadcrumb, truncation notice and nonactivating/click-through overlay settings. These are source checks, not Swift tests.
  - `git branch --show-current`: task/N01-spike. Initial working tree was clean; edits are limited to this review's N01 files. Git emitted a warning about an inaccessible global ignore file during status inspection.
- Mac test steps for the owner:
  1. Check out the manager's N01 round 2 commit on Apple silicon with macOS 26, Xcode 26 and Apple Intelligence ready. Run `swift test --package-path NearMeCore`; require all eight test functions to pass.
  2. Run `xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`. Open the generated NearMe.xcodeproj, select NearMe / My Mac and run. Do not commit the generated project.
  3. Click Open Accessibility Settings, grant NearMe access and relaunch if requested. Place System Settings and NearMe side by side on one display. Activate System Settings, return to NearMe, enter `make text bigger` and click Next step. Confirm the target/window, count <= 120, real chosen role/label, sensible instruction and ring alignment. Record AX/model/total ms and success/failure in docs/LOG.md.
  4. In Xcode, add a source breakpoint on the return expression in AXTraversal.snapshot(windowTitle:). Repeat Next step with the System Settings sidebar visible. Inspect `elements`: rows/cells with no own title/description should use their first static-text descendant within three levels; each breadcrumb should be one nearest labelled ancestor. Use Accessibility Inspector to compare source labels and enabled attributes. Missing AXEnabled must produce isEnabled=true; an explicit false must produce false. Remove/disable the breakpoint before timing checks, because pausing would trip the watchdog.
  5. On a large accessible window, repeat Next step without breakpoints. A read that exhausts the 250 ms walk budget should show "truncated read" and keep any collected elements, permitting planning if nonempty. A genuinely stalled worker may still show the 300 ms timeout error. Record whether budget exhaustion was observed and its AX ms; do not mark this case passed if it was not exercised.
  6. Click Next step then immediately Clear ring, and separately switch target apps during a pending request. Verify no late ring appears. Click a highlighted control yourself and confirm click-through and that the overlay does not take focus. Confirm blank fields/timings use "-" and no em dash appears in authored UI strings.
  7. Check an unavailable Foundation Models configuration or a failed model call leaves a visible error without crashing. Record the real System Settings kill-rule result and latency in docs/LOG.md within the original 60-minute Mac gate.
- Not done / risks / questions: This machine has no Swift or Xcode; GitHub CI is the compile gate. No Swift tests, app build, real AX fixture, watchdog runtime, model inference or ring placement/focus test passed here. Descendant label probes count toward the same 400-visit budget as traversal, so a node can consume another visit when walked later; this is conservative but can shorten a partial snapshot. Synchronous AX calls remain subject to OS scheduling and cannot be forcibly interrupted; the 50 ms headroom avoids the normal equal-deadline race, not every possible stalled IPC. Same-app window changes during inference remain outside N01. Commit is attempted after this report; if .git is read-only, the manager must commit the uncommitted changes.

## Review (round 2)
- Date: 2026-10-24 12:44 AEDT
- Verdict: CHANGES (one owner request; round 1 fixes 1 to 7 all verified in the diff)
- CI run 40051038146 green: 8 tests passed, BUILD SUCCEEDED.

Fixes:
1. Owner decision (PLAN.md Decisions): the AX to AppKit flip stays ONE public function, `ScreenCoordinates.appKitRect(fromAX:mainScreenHeight:)` in NearMeCore, where mainScreenHeight is the primary display height. Do not change its signature or formula. Move it into its own file `NearMeCore/Sources/NearMeCore/ScreenCoordinates.swift` (out of StepValidator.swift). Add a separate test file `NearMeCore/Tests/NearMeCoreTests/ScreenCoordinatesTests.swift` with three named @Test functions. Each test states the display layout in a comment and checks the exact converted rect AND that it lies inside the expected display's AppKit frame (`appKitDisplayFrame.contains(result)`). Primary display is 1440 x 900, AppKit frame (0, 0, 1440, 900), AX frame (0, 0, 1440, 900):
   a. `mainDisplay`: AX (100, 50, 200, 40) gives AppKit (100, 810, 200, 40), inside (0, 0, 1440, 900).
   b. `secondDisplayAbove`: 1920 x 1080 display above the primary, AX frame (0, -1080, 1920, 1080), AppKit frame (0, 900, 1920, 1080). AX (300, -1000, 200, 50) gives AppKit (300, 1850, 200, 50), inside the second display and not inside the primary.
   c. `secondDisplayLeft`: 1920 x 1080 display left of the primary with bottoms aligned, AX frame (-1920, -180, 1920, 1080), AppKit frame (-1920, 0, 1920, 1080). AX (-1800, 100, 200, 50) gives AppKit (-1800, 750, 200, 50), inside the second display and not inside the primary.
   Keep or fold in the existing coordinate test; no duplicate assertions needed.
2. Optional: replace the three `unsafeBitCast` uses CI warns about (AXReader.swift:85, :126, :127) with `unsafeDowncast(_:to:)` only if it compiles cleanly for CF types; otherwise leave them.

## Dev Report (round 3)
- Date: 2026-10-24 12:45 AEDT
- Changed files: NearMeCore/Sources/NearMeCore/StepValidator.swift; NearMeCore/Sources/NearMeCore/ScreenCoordinates.swift; NearMeCore/Tests/NearMeCoreTests/GuidanceTests.swift; NearMeCore/Tests/NearMeCoreTests/ScreenCoordinatesTests.swift; tasks/N01-spike.md. docs/LOG.md will receive one line after a successful commit, as requested.
- What I did (Review round 2, every numbered point):
  1. Moved the single public ScreenCoordinates.appKitRect(fromAX:mainScreenHeight:) function into ScreenCoordinates.swift, retaining its exact signature and formula. Documented that the height is the primary display's height. Added separate mainDisplay, secondDisplayAbove and secondDisplayLeft @Test functions with the requested display-layout comments, exact input/output rectangles, expected-display containment, and secondary-display exclusion from the primary. Replaced the previous coordinate test, retaining its distinct bottom-edge assertion in mainDisplay. Foundation and CoreGraphics are imported in both new files.
  2. Left the three optional unsafeBitCast replacements unchanged: this machine cannot compile the CF-type alternative, and the review permits leaving them unless a clean compile can be confirmed.
- Acceptance criteria (coverage of all original criteria; runtime verification remains pending):
  1. AXPermission trust check and Privacy pane opening remain unchanged.
  2. Bounded off-main-thread AXReader remains unchanged, including the reviewed static-text label exception and 250 ms partial-read / 300 ms watchdog deadlines.
  3. ElementList indices, compact rendering, cap and reader content preference remain unchanged.
  4. Structured Foundation Models step and fresh tool-free session remain unchanged.
  5. StepValidator behavior remains unchanged; only ScreenCoordinates moved out of its file.
  6. Overlay window configuration and conversion call remain unchanged; conversion now has explicit primary/above/left display coverage.
  7. Goal, Next step, element count, chosen element and latency panel remain unchanged.
  8. Last external app tracking and target/window display remain unchanged.
  9. Empty-label-first capping, traversal order and contiguous indices retain existing tests.
  10. Grounded prompt rendering and clarification instructions retain existing tests.
  11. The conversion remains one pure public core function with the same signature and formula, now in ScreenCoordinates.swift.
  12. Existing non-coordinate tests are retained; one coordinate test became three named layout tests, for ten test functions total. Execution is pending CI/Mac.
  13. Role/label/instruction, AX/model timing, Clear ring and error handling remain unchanged.
  14. Nonactivating click-through overlay and absence of AX actions remain unchanged.
  15. Owner gate remains pending; no System Settings success or measured latency is claimed.
- Verify commands run and results:
  - `swift test --package-path NearMeCore`: could not execute; Swift is not installed/recognized.
  - `xcodegen`: could not execute; command unavailable.
  - `xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`: could not execute; Xcode is unavailable. Generation/build were attempted separately in PowerShell.
  - `git diff --check`: initially found extra EOF blank lines after the moves; removed them and reran successfully.
  - PowerShell static checks passed: exactly one public conversion, unchanged signature/formula compared with HEAD, three required test names, three display-containment assertions, two primary-display exclusion assertions, ten total test functions, and no trailing whitespace in either new file. These checks do not execute Swift or CGRect.contains.
  - Read the new tests and implementation, package manifest and overlay call site. SwiftPM discovers the new source/test files without manifest or project changes. Branch is task/N01-spike; initial working tree was clean. Git status warned about an inaccessible global ignore file.
- Mac test steps for the owner:
  1. Check out the manager's round 3 commit on macOS 26 with Xcode 26. From the repository root run `swift test --package-path NearMeCore`; require all ten tests to pass, including mainDisplay, secondDisplayAbove and secondDisplayLeft. These fixtures need no physical secondary display.
  2. Run `xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`; require BUILD SUCCEEDED. Keep NearMe.xcodeproj uncommitted.
  3. Open NearMe.xcodeproj, run NearMe on an Apple Intelligence-ready Mac, grant Accessibility permission, and place NearMe beside System Settings on the primary display. Activate System Settings, return to NearMe, enter `make text bigger`, then click Next step. Check the real chosen label/role, sensible instruction, ring placement and click-through. Record success/failure and AX/model/total ms in docs/LOG.md for the original owner gate.
  4. If secondary displays are available, use System Settings > Displays > Arrange to place one above the primary, then to its left with bottoms aligned. For each arrangement, move the target window onto that display, activate it, return to NearMe and click Next step. Verify the ring follows the selected target control on that display; Clear ring before changing layouts. Record actual layouts and results separately from the unit-test fixtures.
- Not done / risks / questions: This machine has no Swift or Xcode. GitHub CI is the compile gate; the green CI mentioned in Review round 2 predates these changes and does not verify them. New Swift tests, compilation, real multi-display ring placement and the System Settings owner gate remain unverified. The optional cast warnings remain. Commit will be attempted after this report; if the sandbox prevents .git writes, changes must remain uncommitted for the manager.
