# N10: Import prior iOS prototype as NearMe iOS

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct, now, before N04a |
| Depends on | - |
| Assignee | codex |
| Branch | task/N10-ios-import |

## Goal
The prior iPhone prototype (owner decision, used with permission) lives in this repo as a second app target, NearMeiOS, with identical files and behaviour (including its simulated guided walkthrough). Only renaming and build setup change. The macOS NearMe app and NearMeCore stay untouched.

## Read
AGENTS.md (prior-code rule). Source (gitignored, read-only, never commit `_prior/`):
- `_prior/ios/app/`: the app target's sources and `Assets.xcassets` (the original app target compiled this folder plus `Shared/`)
- `_prior/ios/Shared/`: compiled into the app target in the original
- `_prior/ios/broadcast/`: broadcast extension source (never a target in the original)
- `_prior/ios/tests/`: two test files (never attached to a target in the original, so they may never have compiled)

Original app target build settings to reproduce: iOS deployment target 26.5, `TARGETED_DEVICE_FAMILY = 1,2`, `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`, `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor`, `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`, `STRING_CATALOG_GENERATE_SYMBOLS = YES`, `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`, `SWIFT_EMIT_LOC_STRINGS = YES`, `ENABLE_PREVIEWS = YES`, `UIApplicationSupportsIndirectInputEvents = YES`, generated launch screen, `CODE_SIGN_STYLE = Automatic`.

## Acceptance criteria
- [ ] Copy every file (Swift and the full `Assets.xcassets`) into `NearMeiOS/`, same structure: `_prior/ios/app/` -> `NearMeiOS/NearMeiOS/`, `_prior/ios/Shared/` -> `NearMeiOS/Shared/`, `_prior/ios/broadcast/` -> `NearMeiOS/NearMeiOSBroadcastExtension/`, `_prior/ios/tests/` -> `NearMeiOS/NearMeiOSTests/`. No .xcodeproj, xcuserdata, .DS_Store or .bak files
- [ ] Rename only: every old product name (the project name and the second product name used in the permission prompts) in type names, file names, module imports (`@testable import NearMeiOS`), strings, comments, bundle display name and permission prompts becomes NearMe (`NearMeiOS` where a module or target name is needed). All logic, flows, timings and the simulated walkthrough stay identical
- [ ] Every Swift file in `NearMeiOS/` starts with exactly `// Adapted from a prior prototype, used with permission.`; all original header comments and any person's name removed
- [ ] Secrets: delete the Secrets example file and the `Secrets` enum. The key loader reads `ELEVENLABS_API_KEY` from Info.plist (`Bundle.main.object(forInfoDictionaryKey:)`), filled from `Secrets.xcconfig` through the existing `Config/Base.xcconfig`. Empty key keeps the original fallback behaviour. No keys in git
- [ ] project.yml: target `NearMeiOS` (iOS app, deployment 26.5, bundle id `au.nearme.ios`, display name NearMe, `configFiles` = `Config/Base.xcconfig` so `DEVELOPMENT_TEAM` comes from `Config/Team.xcconfig`, the settings above). Sources: `NearMeiOS/NearMeiOS` and `NearMeiOS/Shared` only. Info.plist file `NearMeiOS/NearMeiOS/Info.plist` (custom keys cannot be generated) with `ELEVENLABS_API_KEY = $(ELEVENLABS_API_KEY)`, launch screen, and usage strings:
  - NSMicrophoneUsageDescription: `NearMe listens when you tap the mic so it can understand what you're trying to do on your phone.`
  - NSSpeechRecognitionUsageDescription: `NearMe converts your spoken request into text so it can help you find the right app.`
- [ ] Unit-test target `NearMeiOSTests` (bundle.unit-test, hosted by NearMeiOS) with the two test files. If a test file does not compile against the app, make only the minimal rename or import fix and list it in the Dev Report; never change app logic to make a test pass
- [ ] Broadcast extension source stays in `NearMeiOS/NearMeiOSBroadcastExtension/`, not a target, not in any target's sources
- [ ] A `NearMeiOS` scheme exists (build, test with NearMeiOSTests, run). The macOS `NearMe` target, scheme, NearMeCore and their CI steps are unchanged
- [ ] CI (`.github/workflows/ci.yml`): before any build, select the newest installed Xcode (`ls -d /Applications/Xcode*.app`, pick highest version, `sudo xcode-select -s`) and print `xcodebuild -version` and `xcrun simctl list runtimes`. Keep the existing macOS steps. Add: `xcodebuild -scheme NearMeiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`, then pick the newest available iPhone simulator via `xcrun simctl list devices available -j` (parse with python3 or jq, take the iPhone on the highest iOS runtime) and run `xcodebuild test -scheme NearMeiOS -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO`
- [ ] `scripts/mac-run.sh ios`: git checkout main and pull --ff-only, xcodegen, pick the newest available iPhone simulator (same logic as CI), boot it (ignore "already booted"), `open -a Simulator`, build NearMeiOS for that simulator into `build/`, `xcrun simctl install` and `xcrun simctl launch au.nearme.ios`. This mode needs neither `Config/Team.xcconfig` nor `Secrets.xcconfig`. Update the usage line and README Mac setup with the new mode
- [ ] Name check: `git grep -n -i` for every product name and person name you saw in `_prior/` returns nothing across the repo. Do not write those names in any file, commit message, Dev Report or LOG line; report only "name check: clean" or the file paths that still match

## Verify
```
swift test --package-path NearMeCore
xcodegen
xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme NearMeiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
