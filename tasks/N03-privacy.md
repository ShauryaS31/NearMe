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
