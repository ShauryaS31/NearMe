# P04a: Build fix for Xcode 27.1 / Swift 6.4

| Field | Value |
|---|---|
| Status | done (owner rebuild pending) |
| Window | Sat 24 Oct |
| Depends on | P04 |
| Assignee | manager (mechanical hotfix, owner asked for the smallest change) |
| Branch | fix/P04a-build |

## Goal
P04 failed to build on the Mac (Xcode 27.1, Swift 6.4): with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, default arguments are evaluated nonisolated, so defaults that construct MainActor types or read MainActor statics are errors or warnings. Also stop a locally changed Info.plist from blocking `git pull --ff-only`.

## Changes
- Whole-project scan of every `init`/`func` default argument (multi-line aware) in NearMe/ and NearMeTests/: 7 offending defaults, all in `ElevenLabsVoiceOutput.init` (key, voiceID, settings, cache, player, fallback, deadline) and `VoiceInputRouter.init` (capabilities). `Locale(...)` and `URLSession.shared` defaults are Foundation values and stay. No `nonisolated` type stores a MainActor type.
- Those parameters are now optional with `nil` defaults; the MainActor init body builds the defaults. Call sites (SessionContainerView, tests) unchanged.
- `ElevenLabsVoiceOutput.playableAudioDeadline` and `.modelID` are `nonisolated static let`; `APIKeys` is a `nonisolated enum` (plain values read from Bundle). This also clears the warnings, including the test helper default at NearMeTests/ElevenLabsVoiceOutputTests.swift:289.
- `scripts/mac-run.sh`: before pulling main, a locally changed `NearMe/Info.plist` (build tooling; the Mac never edits code) is restored from git with a message. The committed Info.plist is unchanged LF.

## Verify (Mac)
```
cd ~/NearMe && git checkout -- NearMe/Info.plist && git pull
bash scripts/mac-run.sh test
bash scripts/mac-run.sh quick
```
