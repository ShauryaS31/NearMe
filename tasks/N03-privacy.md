# N03: Privacy filter and blocked contexts

| Field | Value |
|---|---|
| Status | todo |
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
- [ ] Labels longer than 80 chars truncated; emails and phone numbers in labels masked by a small Pseudonymiser in NearMeCore (port the approach from RecalledCore/Sources/RecalledCore/Pseudonymiser in github.com/ShauryaS31/AppleHackathon; owner's own code)
- [ ] Tests: secure field removed, blocked bundle, masked label

## Verify
```
swift test --package-path NearMeCore
```

<!-- Dev Reports and Reviews appended below. -->
