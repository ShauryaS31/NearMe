# P08: "Look at my screen" (stretch, real iPhone only)

| Field | Value |
|---|---|
| Status | dropped (owner 2026-10-24) |
| Window | Sat 24 Oct or Sun 25 Oct before the 13:00 freeze |
| Depends on | P07 |
| Assignee | codex, then owner on a real iPhone |
| Branch | task/P08-look-at-my-screen |

## Goal
When the user is stuck inside another app, one gesture (Back Tap) sends a screenshot to NearMe, which reads the visible labels on device and says the next step, grounded only in what is on screen. The screenshot is never saved.

## Read
AGENTS.md; docs/SPEC.md sections 3 and 4; docs/design/HIG-NOTES.md rules 12, 13. P07's coach state and validators, P02c model helpers, P04 voice output.

## Acceptance criteria
- [ ] App Intent "Ask NearMe about my screen" with an image parameter (`IntentFile`, image content type), exposed through an `AppShortcutsProvider`. It returns spoken dialog (`ProvidesDialog`) and does not open NearMe unless the user taps through
- [ ] Shortcut setup: an in-app "Set up Look at my screen" screen with numbered steps to build the Shortcut (Take Screenshot, then Ask NearMe about my screen) and to assign it to Back Tap (Settings > Accessibility > Touch > Back Tap > Double Tap). Plain words; no private Settings URLs
- [ ] Vision on device: `VNRecognizeTextRequest` (accurate) gives text and bounding boxes; only labels are kept, not images
- [ ] Privacy filter (pure, tested) drops any text that looks like a password or code (6 or more digits, mixed letters and digits of 8 or more characters with no spaces), card numbers (13 to 19 digits with optional spaces or dashes), email addresses and phone numbers. Kept labels are capped (for example 60) and truncated to 40 characters each
- [ ] On-device model (P02c rules: new session, token cap 80, 10 s deadline) picks the next step grounded only in the filtered labels plus the user's current coach goal and step if a coach session is active. Validator: every quoted label must be one of the filtered labels; at most 2 sentences; otherwise "I can't tell from this screen. Try telling me what you want to do."
- [ ] The screenshot exists only in memory for the duration of the intent; never written to disk, Photos, UserDefaults, logs or the voice cache. Logs record counts and ms only
- [ ] Tests (fakes): privacy filter cases; validator; grounding prompt contains only filtered labels and the goal

## Verify (real iPhone)
```
bash scripts/mac-run.sh device --current
```
Owner checks on the iPhone: set up the Shortcut and Back Tap from the in-app steps; in WhatsApp, double tap the back of the phone: NearMe speaks a sensible next step that names a visible label; with a coach session active, the answer fits the current step; a screen showing an email address or code never has it read out.

<!-- Dev Reports and Reviews appended below. -->
