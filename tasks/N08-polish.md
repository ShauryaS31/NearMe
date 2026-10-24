# N08: Craft and demo hardening

| Field | Value |
|---|---|
| Status | todo |
| Window | Sun 25 Oct 10:00 to 13:00 (freeze 13:00) |
| Depends on | N05, N07 |
| Assignee | codex + owner |
| Branch | task/N08-polish |

## Goal
Near shippable feel.

## Read
AGENTS.md; docs/SPEC.md

## Acceptance criteria
- [ ] Onboarding: 3 screens (what NearMe sees, Accessibility permission with a picture, microphone)
- [ ] Animations on ring and panel; reduced motion respected; VoiceOver labels on all controls
- [ ] About screen: what never leaves the Mac, prior-work disclosure, prior prototype acknowledgement
- [ ] Owner: 2 full demo runs on the Mac, one offline; record fallback video

## Verify
```
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
