# NearMe: Plan and Task Board (ACTIVE)

Started Sat 24 Oct 2026 by Shaurya. Fallback if the kill rule fails: Recalled (github.com/ShauryaS31/AppleHackathon, tag `recalled-fallback`).

How we work: code is written on Windows by the factory (Claude Code manager, Codex developer) and pushed to GitHub. The owner tests on the Mac with `scripts/mac-run.sh` and reports results (see docs/MAC-TESTING.md).

## Gates
| Gate | When | Pass condition |
|---|---|---|
| G1 Kill rule | Within 60 min of having the Mac | N01: System Settings elements read, model picks a sensible first step for "make text bigger", ring lands on it. FAIL means return to Recalled |
| G2 Loop | Sat 15:00 | Two-step task completes with re-plan after each click |
| G3 Voice | Sat 18:30 | Local voice and cloned voice both work; offline run passes |
| G4 Numbers | Sat 20:00 | Benchmark CSV with real counts |
| Freeze | Sun 13:00 | No new features |
| Judging | Sun 14:00 | Submit to Community (primary) and Enterprise |

Gate for every task: CI green (NearMeCore tests and NearMe compile on macos-26). Runtime checks go to the "Mac gate checklist" at the bottom of this file; the owner runs them on the Mac.

## Task board
| Task | Title | Window | Depends on | Assignee | Status |
|---|---|---|---|---|---|
| [N00](../tasks/N00-scaffold.md) | Scaffold NearMe repo: XcodeGen, NearMeCore, CI, Mac run script | Sat 24 Oct 12:15 to 13:00 | - | codex | done |
| [N01](../tasks/N01-spike.md) | Spike: read buttons, model picks one, draw ring (kill-rule test) | Sat 24 Oct 13:00 to 14:00 | N00 | codex, then owner on Mac | done (CI); G1 pending Mac |
| [N02](../tasks/N02-loop.md) | Observe and re-plan loop with completion | Sat 24 Oct 13:30 to 15:00 | N01 | codex | todo |
| [N03](../tasks/N03-privacy.md) | Privacy filter and blocked contexts | Sat 24 Oct 14:00 to 15:00 | N01 | codex | done |
| [N10](../tasks/N10-ios-import.md) | Import prior iOS prototype as NearMe iOS (second app target) | Sat 24 Oct, before N04a | - | codex | in_progress |
| [N04a](../tasks/N04a-port.md) | Port prior prototype UI components, speech client, voice output, planner fallback | Sat 24 Oct, after N03 | N01 | codex | todo |
| [N04](../tasks/N04-ui-voice.md) | Help me panel, voice in and out | Sat 24 Oct 15:00 to 17:00 | N02, N04a | codex | todo |
| [N05](../tasks/N05-family-voice.md) | Consented family voice (ElevenLabs) | Sat 24 Oct 17:00 to 18:30 | N04 | codex, then owner | todo |
| [N06](../tasks/N06-hindi.md) | Hindi check (test first, build only if it works) | Sat 24 Oct 18:30 to 19:30 | N04 | owner + codex | todo |
| [N07](../tasks/N07-benchmark.md) | Grounding benchmark and demo tasks | Sat 24 Oct 19:00 to 20:00 | N02 | codex, then owner | todo |
| [N08](../tasks/N08-polish.md) | Craft and demo hardening | Sun 25 Oct 10:00 to 13:00 (freeze 13:00) | N05, N07 | codex + owner | todo |
| [N09](../tasks/N09-scx.md) | STRETCH: SCX fallback for hard goals | Only after N07 | N03 | codex | todo |

## Decisions
- 2026-10-24 (manager proposed, owner APPROVED): AXStaticText's AXValue is read as its label because it is the visible text (System Settings sidebar rows would otherwise be unlabelled). AXValue is never read for any other role. N03 PrivacyFilter still applies on top.
- 2026-10-24 (owner): the AX (top-left) to AppKit (bottom-left) flip is one function in NearMeCore, tested for the main display and a second display above or left of it.

- 2026-10-24 (owner): code from a friend's prior prototype may be reused with her permission. Her name and the original project name must not appear anywhere. Every reused file gets the header "Adapted from a prior prototype, used with permission."; README has a "Prior work" section with the same wording. Replaces the earlier "do not copy" rule in CLAUDE.md and AGENTS.md. Source kept outside git in `_prior/` (gitignored).
- 2026-10-24 (owner): N04a added before N04 and may be built before G1. Order now: N03, then N04a. N02 waits for the owner's G1 report.
- 2026-10-24 (manager): in N04a, on-device speech recognition stays the default; ElevenLabs speech to text is opt-in (setting off by default) to keep SPEC "works offline" and on-device voice input.

- 2026-10-24 (owner): import the prior prototype app from `_prior/` exactly as it is (same files, same behaviour, including the simulated walkthrough) as a second app target, NearMeiOS. Only renaming and build setup change; the macOS NearMe app stays untouched. Task N10, done before N04a; N04a may reuse from `NearMeiOS/` instead of `_prior/`.
- 2026-10-24 (owner, executed by manager): git history rewritten with git filter-repo --replace-text to remove the prior project's names (and a Luma referral token); verified `git log --all -p` clean and Secrets.xcconfig never committed; all branches force-pushed; CI runs on pre-rewrite SHAs deleted. Making the repo public is on hold: GitHub's Activity feed still lists pre-rewrite SHAs (owner decision pending).

## Mac gate checklist
(manager appends PENDING MAC items here)

- [ ] M1 (N00) Launch: `cd ~/NearMe && bash scripts/mac-run.sh`. NearMe window shows "Accessibility trusted", "Foundation Models" and "macOS version" rows with real values.
- [ ] M2 (N00) Signing persists permission: `codesign -dv build/Build/Products/Debug/NearMe.app 2>&1 | grep -E "Authority|TeamIdentifier"` shows "Apple Development" and your Team ID (not "adhoc"). Grant Accessibility, run `bash scripts/mac-run.sh` again, and the row still says Yes.
- [ ] M3 (N01, G1) Setup: open System Settings on any pane, click its window once, then click the NearMe window. "Target app" shows System Settings and "Window" shows its title (not NearMe).
- [ ] M4 (N01, G1 kill rule) Type the goal `make text bigger`, press Next step. Pass: element count above 0, the chosen element is a sensible first step (for example the Accessibility or Displays sidebar row, or Text size if already on that pane), the ring sits exactly on it, and System Settings stays clickable through the ring. Record AX ms and model ms. Repeat 5 times from the General pane; record how many first steps were sensible.
- [ ] M5 (N01) Click the suggested element yourself, click NearMe, press Next step again. A new step and ring appear on the new pane; Clear ring removes it.
- [ ] M6 (N01, only if a second display is available) Move System Settings to the second display, press Next step. The ring lands on the element on that display.
- [ ] M7 (N03) Open Keychain Access, click it, click NearMe, press Next step: status shows "Blocked: ...", no ring, the explanation is spoken once. Then open System Settings > Passwords (or any window titled with "password"): same result.
- [ ] M8 (N10) `cd ~/NearMe && bash scripts/mac-run.sh ios`: the newest iPhone simulator boots and NearMe iOS launches. Complete onboarding (allow microphone and speech when asked), then speak or type "I need to get to Melbourne Central" and walk the guided flow to the end. Pass: every screen and step behaves as in the original prototype, display name and prompts say NearMe.
