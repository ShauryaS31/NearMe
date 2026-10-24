# N11b: Apply HIG to NearMe UI

| Field | Value |
|---|---|
| Status | blocked on N04 and N10 merges |
| Window | After N04 and N10 are merged |
| Depends on | N04, N10, N11a |
| Assignee | codex |
| Branch | current branch when dispatched |

## Goal
Apply docs/design/HIG-NOTES.md to the macOS panel, onboarding, ring overlay and NearMe iOS app. UI presentation only; no behavior changes.

## Read
AGENTS.md; docs/design/HIG-NOTES.md; docs/SPEC.md sections 1 to 5; tasks/N04-ui-voice.md; tasks/N10-ios-import.md; their completed reports and reviews.

## Scope
- Adjust typography, spacing, hit areas, system colors/materials, SF Symbols, accessibility labels, layout and presentation of existing states.
- Preserve session logic, observation/planning/validation, speech/network behavior, permission sequencing, ring interaction and the imported iOS simulated walkthrough.
- If satisfying a HIG rule requires new behavior (for example a missing text-size setting or audio interruption handling), document a deliberate exception and follow-up instead of implementing it here. Record the cross-app floating-panel exception explicitly.

## Acceptance criteria
- [ ] Start only after N04 and N10 are merged; N11a notes are available.
- [ ] Apply the notes to all four surfaces: macOS panel, onboarding, ring, and iOS app.
- [ ] Dev Report has a numbered 1-15 checklist audit: each item is met with evidence for both platforms, or a deliberate exception naming the affected surface, reason and follow-up. Mark platform-inapplicable portions explicitly.
- [ ] No behavior changes; report any appearance/accessibility changes and verify existing flows still work.
- [ ] CI green for the exact commit, including existing NearMeCore tests, macOS compilation, iOS compilation and iOS tests. Record run URL and commit; do not claim local compilation on Windows.
- [ ] Complete HIG1 and HIG2 in docs/PLAN.md. Attach screenshots in light mode, dark mode, Increase Contrast in each appearance and largest text size, plus a combined stress case. Capture macOS panel/onboarding/ring and iOS onboarding/guidance. Record OS/device, settings and screenshot paths; do not substitute desktop scaling for native macOS app text enlargement.

## Verify
Use the repository's current CI workflow and build settings from merged N04/N10. Owner checks VoiceOver and keyboard traversal, hit targets, measured contrast, Reduce Motion/Transparency, truthful permissions/states, audio controls, click-through ring and existing iOS walkthrough. Follow HIG1/HIG2 for screenshot evidence.

<!-- Dev Reports and Reviews appended below. -->
