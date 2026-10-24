# N11a: HIG design notes

| Field | Value |
|---|---|
| Status | done (documentation) |
| Window | Sat 24 Oct, now; independent of N03 |
| Depends on | - |
| Assignee | codex |
| Branch | current branch |

## Goal
Research Apple HIG and write concise, actionable guidance for older, non-technical NearMe users on macOS and iOS. Documentation only; no code changes.

## Read
AGENTS.md; docs/SPEC.md sections 1 to 5; tasks/N04-ui-voice.md; tasks/N10-ios-import.md.

## Acceptance criteria
- [x] Check `codex exec --help`: use Codex web search if offered; otherwise fetch and research Apple sources directly.
- [x] Write docs/design/HIG-NOTES.md, approximately two pages, with a source URL for every rule. Cover overview, accessibility, typography, color, dark-mode, materials, sf-symbols, layout, motion, privacy/requesting permission, onboarding, feedback, panels, windows, buttons, playing-audio, designing-for-macos and designing-for-ios.
- [x] Include text styles and minimums, hit targets, contrast (aim 7:1 for instruction text), system colors, SF Symbols, Reduce Motion/Increase Contrast, VoiceOver, permission explanations, listening/watching/offline states, sound and haptics, tailored to voice-first, one-step guidance, floating panel, ring and iOS.
- [x] End with exactly 15 UI review checklist items.
- [x] Log N11a and N11b in docs/PLAN.md; defer N11b until N04 and N10 are merged; record its CI and screenshot gates.
- [x] Add to AGENTS.md: "All UI work follows docs/design/HIG-NOTES.md."

## Verify
Review all source links, document length and checklist count; run `git diff --check`; confirm changed files are documentation only. No Swift/Xcode execution required for this documentation task; N11b retains the CI compile gate.

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)
- Date: 2026-10-24 13:55 AEDT
- Changed files: `docs/design/HIG-NOTES.md`, `tasks/N11a-hig-design-notes.md`, `tasks/N11b-apply-hig.md`, `docs/PLAN.md`, `AGENTS.md`; `docs/LOG.md` receives the completion entry after the commit.
- What I did: Researched all 18 requested Apple pages from their official Markdown representations and wrote 15 actionable NearMe rules with linked sources and a 15-item review checklist. Created both task briefs, logged their scope/dependencies in PLAN, added HIG1/HIG2 owner gates and the AGENTS UI rule. The user's explicit request authorizes these otherwise restricted PLAN/AGENTS edits. No application code was changed by this task.
- Acceptance criteria:
  1. Research route: `codex exec --help` succeeded and showed no search option, so researched directly. The web tool opened all 18 pages but could not parse their linked `text/markdown` versions; direct HTTPS fetches returned HTTP 200 for all 18. Temporary source copies are outside the repository. The local apple-hig skill was inspected and is a catalogue pointer, not a research workflow.
  2. Coverage/length/sources: all 18 requested URLs are linked; all 15 rules have source references. Approximately 1,040 visible words excluding reference definitions, sized for roughly two pages; exact pagination depends on the Markdown renderer.
  3. NearMe guidance: covers both platforms, one-step voice/text guidance, panel/ring, concrete typography and hit sizes, contrast, colors, symbols, accessibility settings/labels, permission copy, states and sound/haptics. Separates NearMe's stricter targets from Apple's defaults. Notes native macOS lacks Dynamic Type and documents the cross-app panel exception. Does not promise live iOS observation.
  4. Checklist: ends with exactly 15 numbered items, mapped to the sourced rules.
  5. Planning: N11a is documentation-complete; N11b waits for N04/N10 merges, has no behavior changes, requires a 1-15 met/exception audit and exact-commit green CI plus the requested screenshot evidence. Missing behavior is a documented exception/follow-up, not additional implementation scope.
  6. Repository instruction: added exactly "All UI work follows docs/design/HIG-NOTES.md." to AGENTS.md.
- Verify commands run and results: `codex exec --help` passed (with nonfatal temp/PATH warnings; no search option). Direct `Invoke-WebRequest` fetches: 18/18 HTTP 200 after sandbox DNS failure. PowerShell assertions passed for requested topic links, 15 sourced rules, 15 checklist items, AGENTS wording and both briefs; visible word count 1,041. `git diff --check` passed; Git emitted only LF/CRLF normalization warnings. This machine has no Swift or Xcode; no compile, Swift tests, CI run or Mac UI test is claimed. CI remains the project compile gate; N11b runtime evidence is pending.
- Mac test steps for the owner:
  1. Open `docs/design/HIG-NOTES.md` in a Markdown preview; confirm all 15 rules and the final 15-item checklist render, and open each of the 18 Apple source links.
  2. Review the explicit Mac panel exception, Mac text enlargement target and iOS simulation wording against the merged N04/N10 implementation before dispatching N11b.
  3. After N11b, follow HIG1/HIG2 in PLAN: capture each named UI surface in light, dark, increased contrast and largest text configurations; record measured contrast and the numbered checklist audit in its Dev Report. No runtime UI change needs testing for N11a itself.
- Not done / risks / questions: N11b is not started. SPEC remains Mac-first and excludes iPhone; the owner's explicit N10/N11 request supplies iOS scope without editing SPEC. An independent task is modifying iOS/build files in this shared workspace and changed the current branch from `main` to `task/N10-ios-import`; only this task's five documentation files are selected for its commit, on the current branch as instructed. Other task changes are not staged or altered. Native Mac text enlargement and audio/permission behavior gaps must be assessed later without expanding N11b's scope. Screenshot/runtime verification and CI are not available from this Windows-only documentation pass.
