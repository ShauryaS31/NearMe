# NearMe: Spec (Mac-first MVP)

Version 1.0, Saturday 24 October 2026, 11:45 AEDT. Owner: Shaurya V Sharma.
Full background, rubric and prior-art notes: `docs/MASTER-PLAN.md`. Rubric: `docs/RUBRIC.md`.

> **Digital independence, with a familiar voice.**
> NearMe is a voice-first companion that reads the buttons on the screen you're looking at, works out the next step on device, points at it, and says it out loud, optionally in a loved one's consented voice.

## 1. Why Mac-first

On iPhone, a third-party app cannot read or highlight other apps. Screen broadcast gives pixels only, the app is in the background, no overlay. That is what earlier iPhone guidance prototypes already built.
On macOS, with the user's Accessibility permission, an app can read the real interface tree of the frontmost app: every button's role, label and exact frame. So NearMe can:
1. Only ever point at a control that actually exists (grounded, validated).
2. Draw a highlight ring around it.
3. Detect the screen changing and re-plan.

This is the technical differentiator versus earlier iPhone guidance prototypes. Say it plainly in the pitch: "Earlier prototypes proved the need on iPhone. We made it grounded."

## 2. Person and tracks

- **Community (primary):** parents and grandparents who can use a computer but get stuck in unfamiliar apps, often with family far away. Founder story: Shaurya in Sydney, family in India.
- **Enterprise (secondary):** the same engine as an IT helpdesk that guides employees through their own Mac (VPN, printers, settings, internal apps) without screen sharing to a human. Security: on device, only control labels are read, no screenshots. Cost: deflects routine tickets with zero cloud inference. Architecture: grounded validator, privacy filter, optional AU-hosted fallback.

## 3. Demo (target 3 to 5 minutes, confirm limit)

1. **Story (0:20).** Family far away, calls about technology.
2. **Ask (0:40).** Big "Help me" panel. User says "My text is too small, how do I make it bigger?"
3. **Guide (1:30).** NearMe reads System Settings, says "Click Accessibility on the left", draws a ring around it. User clicks. Screen changes, NearMe notices and says the next step. Repeat until the text size changes. NearMe says "Done".
4. **Offline (0:40).** Wi-Fi off. Do a second task (for example turn on Dark Mode). Still works: reading, model and voice all on device.
5. **Familiar voice (0:30).** Wi-Fi on. Same guidance in Shaurya's consented cloned voice via ElevenLabs, labelled "AI voice of Shaurya".
6. **How it works (0:30).** Diagram: interface tree, privacy filter, on-device model, validator, voice. What never leaves the Mac.

Demo tasks are in System Settings because they are useful for older users, safe, and work offline.

## 4. Architecture

```
Mic --> on-device speech to text (English; Hindi if verified)
                    |
                    v  goal text
Frontmost app --> AXReader: flattened elements [id, role, label, frame, enabled]
                    |
                    v
             PrivacyFilter: drop secure text fields and values, block sensitive apps/screens
                    |
                    v
             StepPlanner (Foundation Models, on device, no tools)
               input: goal, app name, window title, numbered element list (max ~120), previous steps
               output: @Generable Step { elementIndex, action, instruction, isGoalComplete, needsClarification }
                    |
                    v
             StepValidator: elementIndex must exist in current list, action allowed (click, type-none, scroll)
                    |
                    v
             Overlay (click-through window, ring at element frame) + Speech (local TTS or ElevenLabs)
                    |
                    v
             AXObserver: focus/window/value changed --> re-read --> plan next step
```

Key choices:
- The model **chooses an index from the real list**; it never invents a label. Validator rejects anything else and asks the user instead.
- NearMe **never clicks for the user.** Guide, do not take over.
- Values are not read: labels and roles only. `AXSecureTextField` and its siblings are dropped. Apps on a block list (banking, password managers, Keychain Access) stop guidance with a message.
- Optional SCX fallback (P2): sanitised element list plus goal, text only, via SCXRuntime, only with consent and an "Online" badge.

## 5. Scope

**P0 (must):** AX permission onboarding; AXReader; PrivacyFilter; StepPlanner with FM; StepValidator; overlay ring; local TTS; AXObserver re-plan loop; completion; Help me panel with typed goal; stop button; works offline. Two System Settings tasks end to end.
**P1:** voice input on device; ElevenLabs cloned voice with consent screen and disclosure, local fallback; Repeat / Slower / I'm stuck buttons; Hindi if verified.
**P2:** SCX fallback; a third-party app task (for example Messages "send a photo"); helpdesk mode screen.
**Non-goals:** clicking for the user, iPhone, recording or storing screens, banking or passwords, Vision Pro.

## 6. Acceptance tests

| # | Test | Expected |
|---|---|---|
| N-A1 | Goal "make text bigger" in System Settings | Correct first element highlighted and spoken |
| N-A2 | User clicks; window changes | New step within 3 s, no stale ring |
| N-A3 | Goal reached | "Done" and ring cleared |
| N-A4 | Requested control not on screen | Asks to clarify or suggests scrolling; never invents |
| N-A5 | Model returns index out of range | Validator rejects, retries once, then asks user |
| N-A6 | Wi-Fi off | Full loop works with local voice |
| N-A7 | ElevenLabs unavailable | Falls back to local voice silently |
| N-A8 | Frontmost app is a password manager | Guidance blocked with explanation |
| N-A9 | Password field visible | Field not in element list sent to model |
| N-A10 | Stop pressed | Observation, ring and speech stop at once |

Report real counts: N attempts, correct first-step rate, step latency, on the actual Mac.

## 7. Risks and kill rule

| Risk | Mitigation |
|---|---|
| System Settings AX tree is huge or nested oddly | Flatten, keep only actionable roles, cap at about 120 elements, prefer focused window |
| On-device model picks wrong element | Better descriptions, include window title and breadcrumbs, few-shot examples; Repeat / I'm stuck |
| Foundation Models unavailable on the loan Mac | Must be Apple silicon, macOS 26+, Apple Intelligence on. Otherwise only a deterministic keyword matcher; disclose |
| Overlay coordinates wrong on multiple displays | Demo on one display; convert AX top-left coordinates to AppKit bottom-left |
| Same as earlier iPhone prototypes | Grounded element tree, highlight, validator, offline, consented family voice |

**Kill rule:** within 60 minutes of the first Mac test, the spike (N01) must read System Settings' elements, have the model choose the right one for "make text bigger", and draw a ring on it. If not, return to Recalled (github.com/ShauryaS31/AppleHackathon, tag `recalled-fallback`).

## 8. Prior work disclosure

New repository started Saturday 24 October 2026. The agent factory process (CLAUDE.md, AGENTS.md, FACTORY.md) and the Pseudonymiser approach come from the owner's Recalled build (github.com/ShauryaS31/AppleHackathon, 23 October). Adapted from a prior prototype, used with permission: shared UI components, the speech client and voice output, and the on-device model with keyword fallback pattern (task N04a). Every adapted file carries that header.
