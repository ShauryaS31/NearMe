# N05: Consented family voice (ElevenLabs)

| Field | Value |
|---|---|
| Status | todo |
| Window | Sat 24 Oct 17:00 to 18:30 |
| Depends on | N04 |
| Assignee | codex, then owner |
| Branch | task/N05-family-voice |

## Goal
Familiar voice online, honest labelling.

## Read
AGENTS.md; docs/SPEC.md

## Acceptance criteria
- [ ] Consent screen: whose voice, who consented, date, revoke button; voice id stored in Keychain
- [ ] ElevenLabs TTS (multilingual model) streaming playback when online; label 'AI voice of <name>' on the panel whenever it plays
- [ ] Fallback to local TTS on any error or offline within 1.5 s
- [ ] Owner: create an Instant Voice Clone of his own voice in the ElevenLabs dashboard (check the attendee plan includes cloning) and put the voice id in Secrets.xcconfig

## Verify
```
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
