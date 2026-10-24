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
| [P03a](../tasks/P03a-fixes.md) | Fixes: accept any place, suggestions only on low confidence or no place, Keep what I said (plus retest findings) | P04 | codex | done (iPhone: Newtown accepted) |
| [P04b](../tasks/P04b-tap-to-finish.md) | Tap to finish speaking, word-based auto-stop, 12 s cap, voice processing, barge-in | P03a | codex | done (iPhone check pending) |
| [P07a](../tasks/P07a-guides.md) | Guide library content: 15 guide JSON files, schema doc, validator (content only) | - | codex (worktree) | done (owner verify-step check pending) |
| [P07](../tasks/P07-guided-coach.md) | Help with any app: guide library (15), router (practice, guide, general), coach session, Open app, new home | P04b, P07a | codex | done (owner compile + 7-phrase check in parallel) |
| [P07b](../tasks/P07b-session-layout.md) | Session layout: full-screen practice and coach, compact bottom dock, target highlight with dim, two-line Debug badge | P07 | codex | done (owner compile and phrase-1 check pending) |
| [P07c](../tasks/P07c-pulse.md) | Target pulse: 3 cycles then static, Repeat replays, Reduce Motion static | P07b | codex | done (Mac check pending) |
| [P07d](../tasks/P07d-router-keyword-override.md) | Router fix: a strong guide match beats a model "general" pick; owner's phrase as acceptance test | P07b | codex | done (combined iPhone check after P11) |
| [P09](../tasks/P09-ui-polish.md) | UI polish: semantic colours, native buttons, type and spacing tokens, Home, voice states, coach card, onboarding | P07b | codex | in_progress (lane worker, worktree ../NearMe-p09, task/P09-ui-polish) |
| [P10](../tasks/P10-ask-widget.md) | "Ask NearMe" widget (Home and Lock Screen) and Siri App Shortcut via nearme://ask | P11 | codex | todo (only if done by Sun 12:00) |
| [P11](../tasks/P11-live-activity-coach.md) | Live Activity coach: Dynamic Island and Lock Screen step with Done | P07b | codex, owner | done (combined iPhone check pending) |
| [P07e](../tasks/P07e-youtube-guide.md) | YouTube guide: play a song (song name, auto-open youtube://) | P11 | codex (Lane A) | in_progress |
| [P12](../tasks/P12-video-practice.md) | Video app practice (unbranded), offered after the YouTube guide | P11 | codex (Lane B, worktree) | in_progress |
| [P05](../tasks/P05-family-voice.md) | Family voice with consent and "AI voice of" label | P04 | codex | todo (after P11; owner recording the voice clone) |
| [P06](../tasks/P06-core-ai.md) | Core AI: task router, grounded help, wrong-tap help, tap and hold, privacy screen | P05, P07 | codex | dropped (privacy screen moved to P05) |
| [P08](../tasks/P08-look-at-my-screen.md) | STRETCH: Look at my screen (App Intent, Back Tap, Vision OCR, privacy filter, grounded step), real iPhone only | P07 | codex, owner | dropped |

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
- 2026-10-24 (owner): P04b (tap to finish speaking, auto-stop by recognised words not loudness, 12 s cap, voice processing, barge-in) right after P03a, before P07. Manager note: keep .playAndRecord with .defaultToSpeaker and use inputNode voice processing, because .voiceChat mode can route NearMe's voice to the earpiece.
- 2026-10-24 (owner): P07 is the top priority, dispatched right after P04b and before P05. Reason: on the phone, "can you help me send an image to my mom" went into the trip flow. Added to P07: exclusive routing (trip flow only on the trip route), 7 router acceptance phrases (unit tests with fake brain and keyword fallback, plus eval), person personalisation ("Open your chat with Mum"), nearby-label steps say "look near", home hint text. Order: P04b, P07, P05, P06, P08.
- 2026-10-24 (owner): device mode picked a booted simulator on Xcode 27.1 (wrong-architecture install). Fixed by the manager in tooling only: connected-iphone.py accepts only physical, paired, connected iPhones (reality physical, platform iOS, and not any simulator UDID from simctl); --device=NAME picks one. macfix 4110302 reviewed: OK.
- 2026-10-24 (owner): P07b (session layout and highlight) right after P07; also applies to the P07 coach screen. Order: P07, P07b, P05, P06, P08.
- 2026-10-24 (owner): after P07 merges, dispatch P07b at once (no stop). Owner runs a quick P07 compile and 7-phrase routing check on the Mac/iPhone in parallel (macfix allowed for compile-only errors); a routing bug found there goes into P07b round 2. The full iPhone check after P07b covers both. P07 review follow-ups are P07b item 0.
- 2026-10-24 (owner): UI upgrade from the Apple HIG research (docs/design/UI-WIDGETS-REPORT.md). P09 UI polish and P10 Ask NearMe widget plus Siri shortcut, after P07b and before P05. Current-step widget, Live Activity and Control Center control deferred (post-freeze P11 if time). Order: P07b, P09, P10, P05, P06; P08 likely dropped.
- 2026-10-24 (owner): FINAL ORDER. 1. P07b (round 2 adds: hidden debug badge, calm step card, auto-open WhatsApp). 2. P11 Live Activity coach (Dynamic Island step and Done). 3. P05 family voice plus the privacy screen (moved from P06; owner is recording the voice clone). 4. P09 UI polish (Sunday morning). 5. P10 widget and Siri shortcut, only if done by Sunday 12:00. Dropped: P06 leftovers, P08. Code freeze Sunday 25 Oct 13:00. The P09/P10 planning files came from the owner's other session; committed to main separately.
- 2026-10-24 (owner): other owner sessions work in their own git worktree or only write under docs/, never in the main folder while the manager has a task running (see CLAUDE.md).
- 2026-10-24 (owner): target ring pulses 3 cycles of about 1.2 s when a step's target first appears, then static; Repeat replays the 3 pulses; Reduce Motion static 6 pt from the start (resolves HIG rule 9). Done as P07c right after P07b (P07b used its 3 review rounds). The manager is now the only manager; the other session stood down. Order confirmed: P07b, P07c, P11, P05 with privacy, P09 Sunday morning, P10 if done by Sun 12:00; P06 and P08 dropped.
- 2026-10-24 (owner): P11 adds nearme:// (nearme://coach?session=<id> resumes, unknown opens Home) and Done while NearMe is not running (intent in app and extension, perform() in the app process against saved progress, no App Group; stop if it would run in the extension). P10 depends on P11, lives in the NearMeLiveActivity extension and uses nearme://ask. The stood-down session's duplicate P07c review (5f50b7d) exists only on the already-merged P07c branch, not on main; its P07c Mac check line is kept; N07b/N07c LOG tags corrected to P07b/P07c.
- 2026-10-24 (owner): P09 runs in parallel as a separate lane worker in worktree ../NearMe-p09 on task/P09-ui-polish; it does not edit PLAN.md or LOG.md and does not merge. The manager reviews and merges it when it reports done (after P11, or before if P11 is still running), resolving CoachView conflicts at merge. P10 still waits for P11. Order otherwise: P11, P05 with privacy, P10.
- 2026-10-24 (owner): iPhone with Apple Intelligence downloaded: phrase 1 routes on the on-device model (2132 ms, first audio 2.68 s). P07d dispatched as a safety net plus 4 bugs: person "Mum" lost, nearby-label wording ("In your Chats list, tap Mum's name", never "look near X and tap it"), auto-open logging and "WhatsApp isn't on this phone", instant acknowledgement line. P11 round 3 adds Activity.update with alertConfiguration so the Island briefly expands on each step. P09: a big per-step icon on the coach card; the icon data goes into P07d (P09's scope guard forbids guide JSON and models), the display into P09's review round after P07d merges.
- 2026-10-24 (owner): merge order P07d, then P11 rebased on P07d, then P09 rebased on both; resolve conflicts in favour of behaviour from P07d/P11 and styling from P09. Check PC memory before each dispatch; if tight, pause the P09 lane first. After P07d and P11 merge, stop for one combined iPhone check (Mum in steps, new wording, instant line, WhatsApp auto-open now that WhatsApp is installed, Live Activity with the Island expanding on each step).
- 2026-10-24 (owner, URGENT, venue closes 19:55): two lanes, minimal scope, one review round each, merge A first. Lane A P07e YouTube guide in the main folder, target merged by 19:35. Lane B P12 video app practice in its own worktree, finish tonight. P09 (task/P09-merged) still held until the owner's combined iPhone report.

## Mac gate checklist
- [x] P01: NearMeTests 4/4 pass on Xcode 27.1, iOS 27.1 simulator (owner).
- [x] P02: full flow works on the simulator (iOS 27); mic needs macOS mic permission for DeviceHub. Findings in tasks/P02-baseline.md.
- [ ] P02c/P02b/P03 retest: steps in the manager's handoff message and each task's Verify section.
- [ ] P04: ElevenLabs voice speaks steps; second run faster (cache); Wi-Fi off gives system voice, no hang; largest text usable on practice screens.
- [ ] P05: switch voices; "AI voice of <name>" label only for the family voice; consent shown once; switching back works.
- [ ] P06: "help me order groceries" gives not-available-yet; "what do I do now" grounded answer; 3 wrong taps give simpler help and pulse; long-press explains; Debug badge shows On-device model and ms.
- [ ] P07: all 7 router phrases route correctly when spoken on the iPhone; image-to-mom coaches with "Mum"; WhatsApp photo request gives the guide, step by step, Done/Repeat/I'm stuck work; ringtone request gives labelled general guidance; Open WhatsApp button; resume after app switch; owner spot-checks 3 guides on the iPhone.
- [ ] P08 (real iPhone): Back Tap Shortcut set up from in-app steps; next step names a visible label; codes and emails never read out.
- [x] P03a (iPhone): "from Central to Newtown" accepted, straight to practice; STT 93 ms, first audio 1.06 s, ElevenLabs. Remaining: a mumbled place gives suggestions plus Keep what I said; a mumbled place gives suggestions plus Keep what I said.
- [ ] P07a: owner checks every step flagged `verify: true` on the iPhone (list in tasks/P07a-guides.md Dev Report).
- [ ] P04b (iPhone, noisy venue): tap, speak, tap captures words over music; barge-in stops NearMe and listens; NearMe never transcribes itself; no words gives the message.
- [ ] P07b: screenshot of each practice step shows the dock, a visible highlight and an unobstructed tab bar (also at the largest text size); Debug badge shows Understood and Voice lines. Also at xxxLarge: tab labels not wrapped or truncated.
- [ ] P09: screenshots of Home, conversation (listening, speaking), coach card, onboarding at default and Accessibility XXXL, light and dark; nothing clipped; Reduce Motion, Reduce Transparency, Bold Text, Button Shapes readable; VoiceOver order on Home.
- [ ] P10 (iPhone): Home and Lock Screen widgets open NearMe listening (closed, backgrounded, locked); mid-guide keeps the guide; "Hey Siri, ask NearMe" works; mic denied gives Type instead and Open Settings.
- [ ] P11 (iPhone): Dynamic Island shows NearMe and step count inside WhatsApp; Done advances; Lock Screen Done and Resume; no names on the Lock Screen; activity ends with the guide.
- [ ] P07c: each practice step's ring pulses 3 times (about 3.6 s) then holds still; dock Repeat and spoken "repeat" pulse again, Slower does not; Reduce Motion on: ring never moves, 6 pt; Debug badge shows Pending before the first turn.
