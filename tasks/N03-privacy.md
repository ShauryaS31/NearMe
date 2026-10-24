# N03: Privacy filter and blocked contexts

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct 14:00 to 15:00 |
| Depends on | N01 |
| Assignee | codex |
| Branch | task/N03-privacy |

## Goal
Never send secrets to the model, never guide on sensitive screens.

## Read
AGENTS.md; docs/SPEC.md

## Acceptance criteria
- [ ] Drop AXSecureTextField elements and never read AXValue of text fields
- [ ] Block list by bundle id (1Password, Bitwarden, Keychain Access, banking apps list) and by window title keywords (password, passcode, bank, payment, card number, OTP); blocked state speaks a short explanation
- [ ] Labels longer than 80 chars truncated; emails and phone numbers in labels masked by a small Pseudonymiser in NearMeCore (port the approach from the owner's own code at `../AppleHackathon/RecalledCore/Sources/RecalledCore/Pseudonymiser.swift`, read-only, relative to this repo root; no prior-prototype header needed, it is the owner's code)
- [ ] `PrivacyFilter` in NearMeCore: `blockReason(bundleID:windowTitle:) -> String?` and `sanitise(_ elements: [ScreenElement]) -> [ScreenElement]`. Pipeline in the app: block check first (before walking the AX tree, using bundle id and focused window title), then AXReader, then sanitise, then ElementList and prompt. Nothing unsanitised reaches the prompt or the panel
- [ ] Bundle ids (exact, case-insensitive): com.1password.1password, com.agilebits.onepassword7, com.bitwarden.desktop, com.apple.keychainaccess, com.apple.Passwords, com.dashlane.dashlanephonefinal. Window title keywords match case-insensitive as whole words or phrases: password, passwords, passcode, bank, banking, netbank, payment, card number, otp, one-time code
- [ ] Blocked: no model call, no ring, panel shows "Blocked: <reason>", and the explanation is spoken once with AVSpeechSynthesizer (for example "I can't help on this screen because it may show private information.")
- [ ] Tests: secure field removed, blocked bundle, blocked title keyword (whole word: "Bankstown" is NOT blocked), masked email and phone label, 80-char truncation, sanitise keeps order and drops nothing else

## Verify
```
swift test --package-path NearMeCore
```

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)
- Date: 2026-10-24 13:40 AEDT
- Changed files: `NearMe/AXReader.swift`, `NearMe/DebugViewModel.swift`, `NearMe/TargetAppTracker.swift`, `NearMeCore/Sources/NearMeCore/PrivacyFilter.swift`, `NearMeCore/Sources/NearMeCore/Pseudonymiser.swift`, `NearMeCore/Tests/NearMeCoreTests/PrivacyTests.swift`, this task file; `docs/LOG.md` receives the requested completion entry.
- What I did: Added the pure-core privacy filter and a small Foundation-only pseudonymiser using the owner's local detector/span-replacement approach. No reverse map or original contact values are retained. Added bundle identity to target tracking, pre-traversal blocking, sanitisation before ElementList construction, and local blocked-state speech. Also masked breadcrumbs, window titles, app names, planner-bound goal text, and displayed model output/errors. An unreadable window title fails closed rather than bypassing the check. All AX work remains in the existing bounded detached worker. No prior-prototype files were used.
- Acceptance criteria:
  1. Secure fields and values: core sanitisation drops `AXSecureTextField`; the reader already rejects secure roles/subroles and their descendants before label lookup. The sole `kAXValueAttribute` query remains guarded by `AXStaticText`, never an editable text-field role.
  2. Sensitive apps/screens and explanation: bundle checks precede AX access, and the focused window title is checked before `walk`. Blocked requests return a fixed explanation that does not echo private UI text.
  3. Contact masking and 80-character limit: `Pseudonymiser.mask` uses local `NSDataDetector` email/telephone spans and backwards replacement. Labels and breadcrumbs are masked before their first 80 Swift characters are retained. Tests cover contacts, repeats, Unicode, and an email spanning the truncation boundary.
  4. API and pipeline: `PrivacyFilter.blockReason(bundleID:windowTitle:)` and `sanitise(_:)` are implemented. The app checks the original context, walks AX, sanitises, then constructs ElementList; only sanitised snapshots leave the reader for the panel and planner. Metadata is also sanitised.
  5. Exact matching: all six specified bundle IDs match case-insensitively and exactly. All ten specified title keywords/phrases use case-insensitive Unicode word boundaries; Bankstown and other substring counterexamples are covered by tests.
  6. Blocked behaviour: early return prevents the planner call; existing rings and prior results are cleared; status is `Blocked: <reason>`. AVSpeechSynthesizer speaks the fixed explanation once per blocked episode (repeated requests with the same reason stay silent; a successful allowed read or target change resets the episode). Clear ring/target changes stop speech.
  7. Tests: seven new Swift Testing functions cover every required case, preserve order/duplicates/empty labels/disabled and unknown roles, verify frames and flags, and check sanitisation before capping and prompt rendering. Execution is pending on Mac/CI.
- Verify commands run and results: `swift test --package-path NearMeCore` attempted and could not run: `swift` is not installed. This machine has no Swift or Xcode; no compile, Swift test, or macOS runtime pass is claimed. `git diff --check` passed. PowerShell static assertions passed for core import restrictions, title-check-before-walk ordering, sanitisation-before-ElementList, and the static-text-only AXValue query. Reviewed all app planner/prompt call sites. GitHub CI remains the compile gate.
- Mac test steps for the owner:
  1. On this branch, run `swift test --package-path NearMeCore`, then `xcodegen`, then `xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`. Confirm the new privacy tests and existing suite pass.
  2. Run the app from Xcode and grant Accessibility permission. Set breakpoints at the first line of `AXTraversal.walk` and at `StepPlanner.plan`. Activate Passwords or an installed listed password manager, return to NearMe, and press Next step. Expect neither breakpoint, no ring, zero elements, hidden window/previous results, `Blocked: ...`, and one audible explanation. Press Next step again: no second explanation.
  3. In Terminal, create a harmless browser fixture with `printf '%s' '<title>Bankstown</title><button>Email alex@example.com</button><button>Call +1 (415) 555-2671</button><input type="password" aria-label="Secure sentinel" value="dummy">' > /tmp/nearme-privacy.html`, then `open -a Safari /tmp/nearme-privacy.html`. Activate Safari, return to NearMe, and press Next step. The traversal/planner breakpoints should now be reached. Inspect the planner's `elements.rendered()` and window title: Bankstown is allowed, contacts are masked, and Secure sentinel/dummy are absent. Inspect chosen-element text for the same masking after continuing.
  4. Change the fixture title using `sed -i '' 's/Bankstown/Payment/' /tmp/nearme-privacy.html`; reload Safari with Command-R and request another step. Expect blocking before either breakpoint and one explanation. Repeat with each keyword from criterion 5, including uppercase and `card number`/`one-time code`; restore Bankstown and confirm guidance resumes.
  5. While blocked speech is playing, press Clear ring or activate a different target app; speech must stop. On a safe System Settings window, request a normal step and confirm normal guidance still works. Repeat contact/truncation checks from the unit suite on the Mac before accepting the change.
- Not done / risks / questions: Runtime/strict-concurrency compilation, detector behaviour on the target OS, AX latency, and audible once-only behaviour require Mac/CI verification. Contact detection is heuristic, not arbitrary-secret anonymisation. The task supplies six password/security-app bundle IDs but no banking-app bundle IDs; the exact supplied list is implemented and banking screens are covered by the specified title keywords. The existing spike reads manually; continuously detecting a same-app window change while planning is outside N03. The new fail-closed title policy may reject apps that do not expose a title.
