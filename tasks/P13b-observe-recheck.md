# P13b: Observe-recheck loop, YouTube only

| Field | Value |
|---|---|
| Status | in_progress (overnight) |
| Window | Sat 24 Oct overnight; owner device test Sun 25 Oct 10:00; kill decision 11:00 |
| Depends on | P13 spike (17440c1, merged), P07e |
| Assignee | codex (main folder) |
| Branch | task/P13b-observe-recheck |

## Goal
Owner, replacing P13 round 2. Prove the core loop for one task, YouTube "play a song": observe the current screen, interpret it, speak one instruction grounded in what is visible, wait for the person, observe again. Never advance because a timer elapsed, an instruction was spoken or Done was pressed.

## Read (first)
AGENTS.md; `docs/ui-mockups/purple-v2/AGENT-HANDOFF.md` (owner direction; read-only, untracked, do not modify or commit it); tasks/P13-see-my-screen.md (spike Dev Report and Review); docs/design/GUIDES.md. Code: `NearMeBroadcastExtension/SampleHandler.swift`, `Shared/SharedScreenBridge.swift` (spike heartbeat), `NearMe/Services/ScreenGuidance/` (ScreenGuidanceService, a stub), `NearMe/ViewModels/TaskPlannerEngine.swift` (coach; steps advance on Done around line 965), `NearMe/Views/Voice/CoachView.swift`, `SessionContainerView.swift` (debug badge), `NearMe/Views/Components/ScreenBroadcastButton.swift`, `NearMe/Views/Onboarding/HowItWorksView.swift`, `NearMe/Resources/guides/youtube_play_song.json`.

Swift 6.4 rules: default arguments must not construct NearMe or test types or read MainActor statics; split long chains over tuples into typed steps; keep SwiftUI bodies small; use resolved stored properties, not optional init parameters. Extension code must be extension-safe.

## Acceptance criteria
### 1. Extension: snapshots
- [ ] About once per second (skip while busy), take the latest video sample, downscale it (long side about 1000 px), run Vision `VNRecognizeTextRequest` inside the extension (`.fast`, language `en`, reuse one request), and drop secrets before writing: lines that look like passwords or codes (4 to 8 digits, mixed letters and digits of 8 or more with no spaces), card numbers (13 to 19 digits with optional spaces or dashes), email addresses, phone numbers, and the line following a label containing "password" or "passcode". At most 60 lines, each at most 80 characters
- [ ] Atomically overwrite ONE `ScreenSnapshot` file in the App Group: `{timestamp, lines: [{text, box}]}` with boxes normalised to 0...1 (top-left origin). Delete it when the broadcast pauses or finishes. Never write frames or images anywhere. The spike heartbeat is replaced by the snapshot (the snapshot's timestamp is the heartbeat)
- [ ] Memory: keep the extension well under the broadcast extension limit (about 50 MB): one reusable request and pixel buffer pool, `autoreleasepool` per frame, no frame retained after processing. Log `os_proc_available_memory()` and processing ms (category "broadcast", no recognised text at `.public`) at most every 10 s, so the owner can read it in Console
- [ ] `ScreenSnapshot` and the secret filter are shared (both targets), pure and unit-tested

### 2. App: ScreenObserver behind one protocol
- [ ] `protocol ScreenSnapshotSource { func latest() -> ScreenSnapshot? }` with ONE implementation `AppGroupScreenSnapshotSource` (reads the App Group file), so a later loopback transport only replaces that file. Owner-approved fallback, not built now
- [ ] `ScreenObserver` polls the source about every 0.5 s while a coach guide is active and sharing is on, publishes the latest snapshot and its age; older than 3 s means "can't see". It reports a changed snapshot when the set of line texts differs from the previous one

### 3. ScreenInterpreter (pure Swift, unit-tested)
- [ ] Input: a snapshot plus the guide (`youtube_play_song`) and request context (song). Output: `ScreenReading { app: knownApp or otherApp or unknown, page, evidence: [String] (the matched words), confidence: Double }`
- [ ] App identity from signature words (YouTube: for example "Home", "Shorts", "Subscriptions", "You", "Search YouTube", "Library"), with rules for "other app" (for example WhatsApp "Chats", Settings "General") and "unknown" when evidence is thin. Page classes for youtube_play_song: `home`, `searchOpen` (for example "Search YouTube" field, keyboard words), `results` (the song's words or result-row patterns such as "views" or a channel line), `watching` (player words such as "Subscribe", "Share", "Comments", "Up next" without the search field), `prompt` (sign-in or consent: "Sign in", "Accept all", "Reject all", "Not now", "Allow"), `otherApp`, `unknown`. Keep the rules data-driven (word lists per page in one place; add an optional `app_signature` and per-step `page` hints to the YouTube guide JSON and validator if useful)
- [ ] Unit tests with fake snapshot sequences: home, then search open, then results, then watching; a sign-in prompt in the middle; WhatsApp (other app); an empty or near-empty snapshot (unknown); confidence lower when evidence is a single word

### 4. Loop in the coach (YouTube guide only; all other guides unchanged)
- [ ] While sharing is on and a fresh snapshot exists, the instruction comes from the OBSERVED page, not the step index: home: "Tap the magnifying glass at the top right." (use the observed box of the search control if a "Search" word or icon label is present: say "top right", "top left" and so on from its box); searchOpen: type the song (P07e song, or ask once if missing), then "Tap search on the keyboard."; results: "Tap the first result" (prefer the row containing the song's words, described by its position); watching: "It should be playing. Is the song playing?" (never claim playback succeeded without evidence or her yes); prompt: handle it first ("A sign-in box has opened. Tap "Not now" to close it.", using the observed button word), then resume
- [ ] After speaking, wait for a changed snapshot or Done. Done triggers a recheck, never a blind advance, while sharing is on. A changed snapshot that maps to the next page advances the coach (Live Activity and Island update as today)
- [ ] Same page and unchanged snapshot for 15 s: a simpler re-prompt (the existing I'm stuck wording for that page), once per 15 s, not more
- [ ] Other app for about 3 s: "It looks like you've left YouTube. Shall I open it again?"; yes re-opens via the auto-open path; no stays. Not repeated while the answer is pending
- [ ] Unknown page: "I'm not sure what's on your screen. What do you see?" and the answer is handled like a typed request within the guide (for example "a sign in box", "search")
- [ ] No capture (sharing off or snapshot older than 3 s): say once "I can't see your screen right now." and continue in manual mode with today's Done-advances behaviour. Nothing in the UI or speech calls this page-aware; show "Screen: off" in the debug line and a small "Manual mode" label on the coach card
- [ ] Never tap or act inside another app

### 5. Debug line
- [ ] DEBUG builds, with the badge shown: "Screen: <age>s | app <x> | page <y> | evidence <words>" (evidence capped at 4 words, at most 40 characters; release builds never show recognised text)

### 6. Honest copy
- [ ] Replace the HowItWorks sentence "It never looks at your other apps." with consent-based wording, exactly: "NearMe shows you practice copies of everyday apps, so you can learn safely. If you turn on 'Let NearMe see my screen', NearMe reads the words on your screen, on this phone, to work out your next step. It keeps only the latest words while sharing is on and deletes them when you stop. You can stop sharing at any time."
- [ ] The same facts in the one-time explanation before the first broadcast (sheet behind "Let NearMe see my screen"). No "nothing is saved", "nothing is recorded" or "everything stays on your phone" claims (the spoken sentence going to ElevenLabs when Natural voice is on stays covered by the existing voice wording). A test proves the snapshot file is deleted on stop

### 7. Tests (default run, fakes)
- [ ] Interpreter sequences above; loop: home, tap, searchOpen (advances only after the changed snapshot), Done on an unchanged home snapshot does NOT advance and re-prompts, prompt handled first, other app gives the reopen offer once, stale snapshot gives "can't see" once and manual mode, 15 s unchanged gives one simpler re-prompt; secret filter; snapshot file write, overwrite and delete

## Out of scope
Live Activity styling, P09, P12, other guides, the loopback transport, raising the iOS minimum.

## Verify
Static checks only on Windows; stop when they pass. Give the owner exact device steps in the Dev Report (signed device build, start sharing, run "play tum hi ho on youtube", what to watch in the debug line and Console for memory).

<!-- Dev Reports and Reviews appended below. -->
