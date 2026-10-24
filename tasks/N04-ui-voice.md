# N04: Help me panel, voice in and out

| Field | Value |
|---|---|
| Status | todo |
| Window | Sat 24 Oct 15:00 to 17:00 |
| Depends on | N02 |
| Assignee | codex |
| Branch | task/N04-ui-voice |

## Goal
Senior-friendly native UI.

## Read
AGENTS.md; docs/SPEC.md

## Acceptance criteria
- [ ] Floating SwiftUI panel: big Help me button, current instruction in large text (Dynamic Type), Repeat, Slower, I'm stuck, Stop
- [ ] Visible status pill: Listening / Watching your screen / Offline / Online voice
- [ ] Voice input with on-device speech recognition (SpeechAnalyzer if available, else SFSpeechRecognizer with requiresOnDeviceRecognition); typed goal fallback
- [ ] Local TTS via AVSpeechSynthesizer, rate adjustable; instructions keep the exact UI label in quotes
- [ ] I'm stuck: re-reads screen and asks the model for a simpler step or a scroll hint

## Verify
```
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
