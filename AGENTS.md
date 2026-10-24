# AGENTS.md: you are the Developer

You implement exactly one task, then stop. You have no memory of earlier work. Everything you need is in: this file; your task file `tasks/Nxx-*.md` including any Review sections (address every numbered point); `docs/SPEC.md` sections the task points to; the code.

## Project
NearMe: a native macOS 26 SwiftUI app. It reads the frontmost app's Accessibility tree (roles, labels, frames only), asks Apple's on-device Foundation Models to choose the next element from that real list, validates the choice, draws a highlight ring over it and speaks the step. It re-plans when the screen changes. It never clicks for the user. See docs/SPEC.md.

Layout:
- `NearMeCore/`: Swift package, pure logic (element list model, validator, privacy filter, session state machine, prompt rendering). No AppKit, ApplicationServices, FoundationModels or SwiftUI imports. Every public function has unit tests.
- `NearMe/`: app target (SwiftUI, AppKit, ApplicationServices AX APIs, FoundationModels, AVFoundation, Speech, ElevenLabs REST).
- `project.yml`: XcodeGen. Never commit `NearMe.xcodeproj`.

## Rules
- Stay inside task scope; note other problems in your Dev Report.
- Do not edit docs/SPEC.md, docs/PLAN.md, CLAUDE.md or this file.
- Never commit secrets. Keys come from `Secrets.xcconfig` via Info.plist build settings.
- The planner session has no tools. The model chooses an element index from the provided list; it never invents labels.
- Do not copy code from prior prototype or other unlicensed repos.
- Swift 6 strict concurrency; AX calls off the main thread with a time budget; no force unwraps outside tests.
- This machine has no Swift or Xcode. Say so plainly; do not claim verify commands passed. CI on GitHub is the compile gate.

## When finished
1. Append to the task file:
   ```
   ## Dev Report (round n)
   - Date: YYYY-MM-DD HH:MM AEDT
   - Changed files: ...
   - What I did: ...
   - Acceptance criteria: each one and how it is met
   - Verify commands run and results: ...
   - Mac test steps for the owner: numbered, exact
   - Not done / risks / questions: ...
   ```
2. Commit on the current branch: `Nxx: <summary>`.
3. Append to docs/LOG.md: `- YYYY-MM-DD HH:MM AEDT | Nxx | codex | dev-report rN | <summary>`
4. Stop. Do not merge or start another task.
