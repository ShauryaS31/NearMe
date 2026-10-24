# N04a: Port prior prototype UI, speech and planner fallback to macOS

| Field | Value |
|---|---|
| Status | todo |
| Window | Sat 24 Oct, after N03, before N04 |
| Depends on | N01 |
| Assignee | codex |
| Branch | task/N04a-port |

## Goal
Reuse proven pieces from a prior iPhone prototype (owner decision, used with permission) so N04 only wires screens, instead of writing UI, speech and planner fallback from scratch.

## Read
AGENTS.md (prior-code rule); docs/SPEC.md sections 4 and 5; the source in `_prior/` (gitignored, read-only reference, never commit it):
- `_prior/ui/`: Theme.swift, ScreenScaffold.swift, PrimaryButton.swift, CaptionBubble.swift, VoiceOrbView.swift
- `_prior/colors/*.json`: asset-catalog colour definitions (light and dark sRGB values) used by Theme.swift
- `_prior/speech/`: ElevenLabsScribeService.swift (speech to text), AudioFileRecorder.swift, AppleSpeechFallbackService.swift, VoiceInputRouter.swift, VoiceInputService.swift, VoiceOutputService.swift
- `_prior/planner/`: TaskPlannerBrain.swift (protocol, resilient wrapper, factory), FoundationModelsBrain.swift, KeywordFallbackBrain.swift, KeywordFallbackBrainTests.swift

## Naming and attribution (hard rules)
- Every new file that adapts `_prior/` code starts with exactly: `// Adapted from a prior prototype, used with permission.`
- Strip every original header comment. No author names, no original project or product names, no transport, journey or station references anywhere (code, comments, strings, tests, commit message, Dev Report, LOG). Product name in strings is "NearMe".
- Rename types to NearMe naming: `TT*` prefixes become `NM*` (NMColor, NMFont, NMSpacing, NMRadius); services get NearMe names (for example `SpeechToTextClient`, `VoiceInput`, `VoiceOutput`).

## Acceptance criteria
- [ ] UI in `NearMe/UI/`: NMTheme (colours defined in code from `_prior/colors` with light and dark variants via NSColor dynamic provider, no asset catalog needed; fonts; spacing; radius; minimum hit target modifier), ScreenScaffold, PrimaryButton, CaptionBubble, VoiceOrbView. macOS only: no UIKit, no `ignoresSafeArea` dependence on iOS, no haptics. Each has a `#Preview`
- [ ] Speech in `NearMe/Speech/`:
  - `SpeechToTextClient` (ElevenLabs speech to text REST, multipart upload). Key read from Info.plist `ELEVENLABS_API_KEY`; empty key means unavailable. No force unwraps (the source has one on the URL)
  - Audio recorder and on-device recognizer ported to macOS: no AVAudioSession anywhere (it does not exist on macOS); on-device recognizer sets `requiresOnDeviceRecognition = true`
  - `VoiceInput` router: **on-device recognition is the default**. ElevenLabs is used only when a `useOnlineTranscription` setting is true (default false) AND a key is present; if it throws, fall back to on-device. (SPEC: works offline, voice input on device)
  - `VoiceOutput`: AVSpeechSynthesizer, adjustable rate, `stop()` stops at once, no AVAudioSession
- [ ] Planner fallback pattern, adapted to NearMe steps (not intents):
  - NearMeCore (pure, tested): `StepChoice { elementIndex, action, instruction, isGoalComplete, needsClarification }` and `KeywordStepPlanner` that scores `ElementList` labels and breadcrumbs against goal words (lowercased, stop words removed) plus a small synonym table (for example bigger/larger/size/text/font -> Display, Text size, Accessibility). Highest score wins, ties go to the lower index; score 0 gives needsClarification with an instruction asking the user to say it another way. Instruction quotes the exact label, for example `Click "Accessibility".`
  - App target: `StepPlanning` protocol; the N01 Foundation Models planner conforms; `ResilientStepPlanner` tries primary then fallback on throw; a factory returns resilient(FM, keyword) when the model is available, else keyword only. The output always passes `StepValidator`
  - Debug panel shows which planner produced the step: "On-device model" or "Keyword fallback" (so the G1 test cannot be passed by the fallback unnoticed)
- [ ] Hardened runtime microphone access: add an entitlements file with `com.apple.security.device.audio-input` = true, referenced in project.yml (sandbox stays off)
- [ ] Tests in NearMeCore: KeywordStepPlanner picks "Accessibility" or "Display" for "make text bigger" from a fixture list, picks by exact label match, returns needsClarification on no match, tie goes to lower index, never returns an index outside the list
- [ ] Not ported: the simulated third-party app screens, the app launcher, ReplayKit, the broadcast extension, onboarding screens, the audio session file, progress dots
- [ ] No identifying names: `git grep -n -i` over the branch for the original names returns nothing (manager checks)

## Verify
```
swift test --package-path NearMeCore
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
