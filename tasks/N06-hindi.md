# N06: Hindi check (test first, build only if it works)

| Field | Value |
|---|---|
| Status | todo |
| Window | Sat 24 Oct 18:30 to 19:30 |
| Depends on | N04 |
| Assignee | owner + codex |
| Branch | task/N06-hindi |

## Goal
Only claim Hindi if every stage works.

## Read
AGENTS.md; docs/SPEC.md

## Acceptance criteria
- [ ] Owner tests on the Mac: Foundation Models answers a Hindi or Hinglish goal sensibly; on-device speech recognition for hi-IN; a Hindi system voice installed
- [ ] If FM works: instruction language setting (English, Hindi), UI labels kept exactly as shown
- [ ] If only ElevenLabs Hindi works: Hindi spoken online only, labelled
- [ ] Record the capability matrix in docs/nearme/hindi.md with what was actually tested

## Verify
```
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
