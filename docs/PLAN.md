# NearMe: Plan and Task Board (ACTIVE, iPhone)

Pivoted to iPhone on Sat 24 Oct 2026. The macOS work (N00 to N11) is parked on branch `archive/mac-nearme`; do not delete it.

How we work: code is written on Windows by the factory (Claude Code manager, Codex developer) and pushed to GitHub. The owner's Mac is the test gate: `scripts/mac-run.sh` (docs/MAC-TESTING.md). GitHub CI is manual only (workflow_dispatch) to save minutes; run it only when the owner asks.

## Milestones
| When | What |
|---|---|
| Sat 24 Oct | P01 import, P02 baseline on the Mac |
| After P02 review | Owner picks P03 onwards |
| Sun 25 Oct 13:00 | Freeze: no new features |
| Sun 25 Oct 14:00 | Judging: submit to Community (primary) and Enterprise |

Gate for every task: the owner's Mac checks pass (simulator, and iPhone when available).

## Task board
| Task | Title | Depends on | Assignee | Status |
|---|---|---|---|---|
| [P01](../tasks/P01-ios-import.md) | Import the prior iPhone prototype as NearMe | - | codex, manager | in_review (Mac pending in P02) |
| [P02](../tasks/P02-baseline.md) | Baseline test on Mac (simulator + iPhone if available): what works, what breaks | P01 | owner, manager | todo |

P03 onwards: empty until the owner reviews P02.

## Decisions
- 2026-10-24 (owner): PIVOT to the iPhone. Start from the prior prototype app and improve it. macOS NearMe parked on `archive/mac-nearme`. macOS code (NearMe/, NearMeCore/) and tasks N00 to N11 removed from main.
- 2026-10-24 (owner): prior prototype code may be reused with permission. The author's name and the original project name must not appear anywhere. Every reused file has the header "Adapted from a prior prototype, used with permission."; README has a "Prior work" section with the same wording. Source kept outside git in `_prior/` (gitignored).
- 2026-10-24 (owner): import exactly; only renaming and build setup change. Keys from `Secrets.xcconfig` via Info.plist, not Secrets.swift. Broadcast extension source kept, not a target yet.
- 2026-10-24 (owner): CI manual only; the Mac is the gate. Repo stays private for now.
- 2026-10-24 (owner, executed by manager): history rewritten earlier with git filter-repo to remove the prior project's names; verified clean; force-pushed. Making the repo public is deferred (GitHub's Activity feed still lists pre-rewrite SHAs; recreating the repo is the agreed fix when going public).

## Mac gate checklist
- [ ] P01/P02: see tasks/P02-baseline.md checks 1 to 12.
