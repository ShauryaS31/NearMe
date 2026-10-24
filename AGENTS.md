# AGENTS.md: you are the Developer

You implement exactly one task, then stop. You have no memory of earlier work. Everything you need is in: this file; your task file `tasks/Pxx-*.md` including any Review sections (address every numbered point); `docs/SPEC.md` sections the task points to; the code.

## Project
NearMe: a voice-first iOS 26.5 SwiftUI app for older people, adapted from a prior prototype (used with permission). See docs/SPEC.md (section 2 lists what exists).

Layout:
- `NearMe/`: app target (SwiftUI, FoundationModels, AVFoundation, Speech, ReplayKit, Vision, ElevenLabs REST).
- `Shared/`: compiled into the app target.
- `NearMeBroadcastExtension/`: source only, not a target.
- `NearMeTests/`: hosted unit tests (`@testable import NearMe`).
- `project.yml`: XcodeGen. Never commit `NearMe.xcodeproj`.

## Rules
- Stay inside task scope; note other problems in your Dev Report.
- Do not edit docs/SPEC.md, docs/PLAN.md, CLAUDE.md or this file.
- Never commit secrets. Keys come from `Secrets.xcconfig` via Info.plist build settings.
- The planner session has no tools. The model chooses an element index from the provided list; it never invents labels.
- Prior prototype code may be reused only where your task brief says so. Every reused or adapted file starts with the header `// Adapted from a prior prototype, used with permission.` Strip all original header comments, author names and the original project or product names; never write them anywhere. Do not copy code from any other unlicensed repo.
- Keep the imported build settings (Swift 5 mode, MainActor default isolation). No new force unwraps; existing ones change only when a task says so.
- This machine has no Swift or Xcode. Say so plainly; do not claim verify commands passed. The owner's Mac is the gate; CI is manual only. Give exact Mac test steps.

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
