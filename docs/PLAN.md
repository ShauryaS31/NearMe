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
| [P04](../tasks/P04-elevenlabs-voice.md) | ElevenLabs voice (cache, prefetch, 2.5 s fallback) and rough edges | P03 | codex | done (Mac check pending) |
| [P04a](../tasks/P04a-build-fix.md) | Build fix for Xcode 27.1 / Swift 6.4 (MainActor default arguments), Info.plist no longer blocks pull | P04 | manager | done (macfix 5cd50e5; builds, 77 tests pass, 1 skip) |
| [P03a](../tasks/P03a-fixes.md) | Fixes: accept any place, suggestions only on low confidence or no place, Keep what I said (plus retest findings) | P04 | codex | done (Mac check pending) |
| [P07a](../tasks/P07a-guides.md) | Guide library content: 15 guide JSON files, schema doc, validator (content only) | - | codex (worktree) | in_progress |
| [P07](../tasks/P07-guided-coach.md) | Help with any app: guide library (15), router (practice, guide, general), coach session, Open app, new home | P03a, P07a | codex | todo |
| [P05](../tasks/P05-family-voice.md) | Family voice with consent and "AI voice of" label | P04 | codex | todo |
| [P06](../tasks/P06-core-ai.md) | Core AI: task router, grounded help, wrong-tap help, tap and hold, privacy screen | P05, P07 | codex | todo |
| [P08](../tasks/P08-look-at-my-screen.md) | STRETCH: Look at my screen (App Intent, Back Tap, Vision OCR, privacy filter, grounded step), real iPhone only | P07 | codex, owner | todo (only after P07 passes) |

Now: owner compiles and retests P02c, P02b and P03 on the Mac. P04 starts when that passes; then P05, P06, stopping after each for the owner's Mac check.

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

- 2026-10-24 (owner): new tasks P04 (ElevenLabs voice and rough edges), P05 (consented family voice), P06 (Core AI: router, grounded help, wrong-tap help, tap and hold, privacy). Start P04 once the current Mac check passes; stop after each task for the owner's Mac check. Gate for each: `bash scripts/mac-run.sh quick` builds and launches and default tests pass.
- 2026-10-24 (owner): all P04 to P06 brief choices approved. Voice input is always on-device (ElevenLabs speech-to-text removed, in P04), because recorded speech must not leave the phone. Settings toggle "Natural voice (online)": off means only the system voice and nothing leaves the phone (logic in P04, toggle in P05). P06 privacy copy is the owner's exact wording, naming place names sent to ElevenLabs.
- 2026-10-24 (owner): Apple speech must run strictly on-device (requiresOnDeviceRecognition = true or SpeechAnalyzer); if on-device recognition is unavailable for the locale, show Type instead, never a server. Added to P04.
- 2026-10-24 (owner): start P04 now without waiting for the P02c/P02b/P03 retest (running in parallel). Retest issues become P03a, done right after P04. Stop after P04 for the owner's Mac check.
- 2026-10-24 (owner): NearMe must help with any task, not one scripted flow. New P07 (guided coach for any app) after P04 and before P05; P07's router replaces P06 item 1. P08 (look at my screen, stretch, real iPhone only) starts only after P07 passes. Order: P04, P07, P05, P06, then P08. Manager notes: guides carry verified_on_device (false until the owner checks on the iPhone); Settings guides cannot deep-link (no private App-prefs URLs).
- 2026-10-24 (owner): Did you mean accepts any place the user says (practice, any destination is fine); suggestions only on low recogniser confidence or no recognisable place, showing the transcript, up to 2 closest matches and Keep what I said. In P03a, right after P04. Order: P04, P03a, P07, P05, P06, P08.
- 2026-10-24 (owner): P04 build failed on Xcode 27.1 / Swift 6.4 (default arguments constructing MainActor types). P04a fixes all instances (manager hotfix, smallest change). The model returning "nil" as a place goes into P03a.
- 2026-10-24 (owner): macfix rule. The Mac tester may fix compile-only errors (no behaviour or logic change) directly on main with commit prefix `macfix:`, push and log a line in docs/LOG.md; the manager reviews every macfix commit on resume. Anything beyond a compile fix comes to the manager. First use: ElevenLabsVoiceOutput.swift:81-82 (P04a used the optional init parameters instead of self.player and self.fallback).
- 2026-10-24 (owner): start P03a now from main (rebase onto the macfix commit before merging). In parallel, P07a writes the 15 guide JSON files and schema doc (content only) on task/P07a-guides. Schema: last_checked and per-step verify replace verified_on_device. Stop after P03a merges for the owner's Mac check; P07a reviewed then too.

## Mac gate checklist
- [x] P01: NearMeTests 4/4 pass on Xcode 27.1, iOS 27.1 simulator (owner).
- [x] P02: full flow works on the simulator (iOS 27); mic needs macOS mic permission for DeviceHub. Findings in tasks/P02-baseline.md.
- [ ] P02c/P02b/P03 retest: steps in the manager's handoff message and each task's Verify section.
- [ ] P04: ElevenLabs voice speaks steps; second run faster (cache); Wi-Fi off gives system voice, no hang; largest text usable on practice screens.
- [ ] P05: switch voices; "AI voice of <name>" label only for the family voice; consent shown once; switching back works.
- [ ] P06: "help me order groceries" gives not-available-yet; "what do I do now" grounded answer; 3 wrong taps give simpler help and pulse; long-press explains; Debug badge shows On-device model and ms.
- [ ] P07: WhatsApp photo request gives the guide, step by step, Done/Repeat/I'm stuck work; ringtone request gives labelled general guidance; Open WhatsApp button; resume after app switch; owner spot-checks 3 guides on the iPhone.
- [ ] P08 (real iPhone): Back Tap Shortcut set up from in-app steps; next step names a visible label; codes and emails never read out.
- [ ] P03a: "from Central to Newtown" accepted with no suggestions; a mumbled place gives suggestions plus Keep what I said.
- [ ] P07a: owner checks every step flagged `verify: true` on the iPhone (list in tasks/P07a-guides.md Dev Report).
