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
| [N01](../tasks/N01-spike.md) | Spike: read buttons, model picks one, draw ring (kill-rule test) | Sat 24 Oct 13:00 to 14:00 | N00 | codex, then owner on Mac | in_progress |
| [N02](../tasks/N02-loop.md) | Observe and re-plan loop with completion | Sat 24 Oct 13:30 to 15:00 | N01 | codex | todo |
| [N03](../tasks/N03-privacy.md) | Privacy filter and blocked contexts | Sat 24 Oct 14:00 to 15:00 | N01 | codex | todo |
| [N04](../tasks/N04-ui-voice.md) | Help me panel, voice in and out | Sat 24 Oct 15:00 to 17:00 | N02 | codex | todo |
| [N05](../tasks/N05-family-voice.md) | Consented family voice (ElevenLabs) | Sat 24 Oct 17:00 to 18:30 | N04 | codex, then owner | todo |
| [N06](../tasks/N06-hindi.md) | Hindi check (test first, build only if it works) | Sat 24 Oct 18:30 to 19:30 | N04 | owner + codex | todo |
| [N07](../tasks/N07-benchmark.md) | Grounding benchmark and demo tasks | Sat 24 Oct 19:00 to 20:00 | N02 | codex, then owner | todo |
| [N08](../tasks/N08-polish.md) | Craft and demo hardening | Sun 25 Oct 10:00 to 13:00 (freeze 13:00) | N05, N07 | codex + owner | todo |
| [N09](../tasks/N09-scx.md) | STRETCH: SCX fallback for hard goals | Only after N07 | N03 | codex | todo |

## Mac gate checklist
(manager appends PENDING MAC items here)

- [ ] M1 (N00) Launch: `cd ~/NearMe && bash scripts/mac-run.sh`. NearMe window shows "Accessibility trusted", "Foundation Models" and "macOS version" rows with real values.
- [ ] M2 (N00) Signing persists permission: `codesign -dv build/Build/Products/Debug/NearMe.app 2>&1 | grep -E "Authority|TeamIdentifier"` shows "Apple Development" and your Team ID (not "adhoc"). Grant Accessibility, run `bash scripts/mac-run.sh` again, and the row still says Yes.
