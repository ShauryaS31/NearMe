# N01: Spike: read buttons, model picks one, draw ring (kill-rule test)

| Field | Value |
|---|---|
| Status | in_progress |
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
