# NearMe: Plan and Task Board (ACTIVE, iPhone)

Pivoted to iPhone on Sat 24 Oct 2026. The macOS work (N00 to N11) is parked on branch `archive/mac-nearme`; do not delete it.

How we work: code is written on Windows by the factory (Claude Code manager, Codex developer) and pushed to GitHub. The owner's Mac is the test gate: `scripts/mac-run.sh` (docs/MAC-TESTING.md). GitHub CI is manual only (workflow_dispatch) to save minutes; run it only when the owner asks.

## Milestones
| When | What |
|---|---|
| Sat 24 Oct | P01 import, P02 baseline on the Mac |
| After P02 review | P02a, P02c, P02b, then P03 |
| Sun 25 Oct 13:00 | Freeze: no new features |
| Sun 25 Oct 14:00 | Judging: submit to Community (primary) and Enterprise |

Gate for every task: the owner's Mac checks pass (simulator, and iPhone when available).

## Task board
| Task | Title | Depends on | Assignee | Status |
|---|---|---|---|---|
| [P01](../tasks/P01-ios-import.md) | Import the prior iPhone prototype as NearMe | - | codex, manager | done (Mac: 4/4 tests pass) |
| [P02](../tasks/P02-baseline.md) | Baseline test on Mac (simulator + iPhone if available): what works, what breaks | P01 | owner, manager | done |
| [P02a](../tasks/P02a-debug-parsing-facts.md) | Debug badge, real voice errors, Type instead; trip parsing fixes; no invented facts | P02 | codex | done (Mac compile OK) |
| [P02c](../tasks/P02c-model-calls-eval.md) | Bounded model calls (fresh session, token cap, 10 s timeout), latency in badge, model eval behind NEARME_MODEL_EVAL, `eval` mode | P02a | codex | done (Mac compile pending) |
| [P02b](../tasks/P02b-onboarding-text-copy.md) | Onboarding at largest text sizes; honest explainer copy; `quick` mode in mac-run.sh | P02c | codex | done (Mac compile pending) |
| [P03](../tasks/P03-generic-trip-planner.md) | Rebrand practice screens to a generic Trip planner with Sydney places | P02b | codex | done (Mac compile pending) |

Now: owner compiles and retests P02c, P02b and P03 on the Mac. Nothing else is planned until then.

## Decisions
- 2026-10-24 (owner): PIVOT to the iPhone. Start from the prior prototype app and improve it. macOS NearMe parked on `archive/mac-nearme`. macOS code (NearMe/, NearMeCore/) and tasks N00 to N11 removed from main.
- 2026-10-24 (owner): prior prototype code may be reused with permission. The author's name and the original project name must not appear anywhere. Every reused file has the header "Adapted from a prior prototype, used with permission."; README has a "Prior work" section with the same wording. Source kept outside git in `_prior/` (gitignored).
- 2026-10-24 (owner): import exactly; only renaming and build setup change. Keys from `Secrets.xcconfig` via Info.plist, not Secrets.swift. Broadcast extension source kept, not a target yet.
- 2026-10-24 (owner): Mac toolchain is Xcode 27.1 with the iOS 27.1 simulator; Xcode 27 uses DeviceHub.app instead of Simulator.app.
- 2026-10-24 (owner): CI manual only; the Mac is the gate. Repo stays private for now.
- 2026-10-24 (owner, executed by manager): history rewritten earlier with git filter-repo to remove the prior project's names; verified clean; force-pushed. Making the repo public is deferred (GitHub's Activity feed still lists pre-rewrite SHAs; recreating the repo is the agreed fix when going public).

- 2026-10-24 (owner): P02a now (debug badge, real errors, Type instead, parsing fixes, no invented facts), then P03 (generic Trip planner, Sydney places). Gate: builds on the Mac; owner retests.
- 2026-10-24 (owner): no CI. After each merge, stop and wait for the owner's Mac compile check before the next task. P02b (large text onboarding, honest explainer) added after P02a, before P03.

- 2026-10-24 (owner): Mac compile of P02a OK; Foundation Models is available in the simulator. The real-model test ran over 9 minutes and hit "transcript exceeded the model's context size" at about 7 minutes. P02c fixes this before P02b: fresh bounded session per call, latency logging and badge, model eval behind NEARME_MODEL_EVAL=1 with an `eval` mode. Then P02b (with `quick` mode), then P03.

## Mac gate checklist
- [x] P01: NearMeTests 4/4 pass on Xcode 27.1, iOS 27.1 simulator (owner).
- [x] P02: full flow works on the simulator (iOS 27); mic needs macOS mic permission for DeviceHub. Findings in tasks/P02-baseline.md.
- [ ] P02c/P02b/P03 retest: steps in the manager's handoff message and each task's Verify section.
