# N00: Scaffold NearMe repo: XcodeGen, NearMeCore, CI, Mac run script

| Field | Value |
|---|---|
| Status | todo |
| Window | Sat 24 Oct 12:15 to 13:00 |
| Depends on | - |
| Assignee | codex |
| Branch | task/N00-scaffold |

## Goal
A buildable empty NearMe macOS app so every later task only adds code, plus a one-command way for the owner to test on the Mac.

## Read
AGENTS.md; docs/SPEC.md sections 1, 4, 5

## Acceptance criteria
- [ ] `project.yml` (XcodeGen): target `NearMe`, macOS 26 SwiftUI app, App Sandbox OFF (Accessibility APIs need it), hardened runtime on, bundle id `au.nearme.app`, `DEVELOPMENT_TEAM` read from `Config/Team.xcconfig` (gitignored, example committed) so the owner's Personal Team signs it and the Accessibility permission survives rebuilds. `NearMe.xcodeproj` is gitignored and generated
- [ ] Local Swift package `NearMeCore/` (swift-tools 6.0, macOS 26) with no AppKit, ApplicationServices or FoundationModels imports; one placeholder type and test
- [ ] `Secrets.xcconfig` (gitignored) included via build settings; keys exposed to Info.plist as `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`, `SCX_API_KEY`
- [ ] Info.plist: NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription with NearMe wording
- [ ] App launches to a placeholder window showing: Accessibility trusted yes/no, Foundation Models availability, macOS version
- [ ] `.github/workflows/ci.yml` on `macos-26`: `swift test --package-path NearMeCore`, then `xcodegen` and `xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- [ ] `scripts/mac-run.sh` (already present, review and keep working with the real project)
- [ ] README: Mac setup (brew install xcodegen, copy Secrets.xcconfig and Config/Team.xcconfig, run scripts/mac-run.sh)

## Verify
```
swift test --package-path NearMeCore
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
