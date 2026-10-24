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

## Dev Report (round 1)
- Date: 2026-10-24 13:57 AEDT
- Changed files: `NearMeiOS/` (48 Swift files, 15 asset catalog files, and the app Info.plist); `project.yml`; `.github/workflows/ci.yml`; `scripts/mac-run.sh`; `scripts/newest-iphone.py`; `README.md`; this task file. The required LOG entry follows the commit if Git can write. Concurrent N11a documentation changes and its LOG entry are not part of this implementation.
- What I did: Imported the four supplied source folders as the independent NearMeiOS app, shared sources, reference-only broadcast source, and hosted tests. Applied only header removal, product/person renaming, the required key-loader replacement, and build/run configuration. The default greeting now uses `Friend` to remove the original person's name. The welcome wordmark uses `Near` and `Me` in the original layout. The simulated walkthrough, state transitions, delays, speech routing, and other app logic remain unchanged.
- Acceptance criteria:
  1. Copied all 48 Swift files and all 15 asset files into the requested structure, excluding the supplied Secrets example. There was no separate Secrets enum source in the supplied snapshot. No project bundle, user data, `.DS_Store`, or `.bak` files were imported. A full source/destination inventory assertion passed.
  2. Renamed product references in source, filenames, comments, strings, identifiers, and test module imports. Comparison against the originals passed after only the required transformations; all asset files are byte-identical. The app display name is NearMe.
  3. All 48 Swift files begin with the exact required adaptation header. Original leading comment blocks and person names were removed.
  4. `APIKeys.swift` reads `Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_API_KEY")`, defaulting to an empty string. Info.plist substitutes the build setting from the unchanged `Config/Base.xcconfig` optional Secrets include. The existing empty-key Apple speech fallback is unchanged; no Secrets enum/example or key literal was imported.
  5. Added the iOS 26.5 application target, bundle ID `au.nearme.ios`, both Base.xcconfig configurations, every requested original build setting, and the custom Info.plist with the exact usage descriptions, launch screen, indirect-input flag, and key substitution. Only the app and Shared directories are app sources.
  6. Added the hosted `NearMeiOSTests` target and both supplied files. The only test-source change beyond required header/name removal is `@testable import NearMeiOS`. `JourneyIntentTests.swift` has four tests; `KeywordFallbackBrainTests.swift` was supplied with only `import Foundation` and remains that way. Compilation is pending CI; no app logic was changed to accommodate tests.
  7. The broadcast source remains in `NearMeiOS/NearMeiOSBroadcastExtension/` and is excluded from every target. No extension target was created.
  8. Added a NearMeiOS build/test/run scheme. Parsed configuration comparisons confirmed the macOS target, macOS scheme, package declaration, and existing CI steps are unchanged; NearMe and NearMeCore have no code changes.
  9. CI enumerates installed Xcode apps, chooses the highest actual bundle version, selects it before Swift tests/builds, and prints Xcode and runtime versions. Added the exact unsigned iOS build and hosted test commands. Both CI and the local helper use the same simulator JSON parser to select an available iPhone on the highest iOS runtime.
  10. `mac-run.sh ios` checks out main and pulls with `--ff-only`, generates the project, selects/boots the simulator, tolerates the already-booted result, waits for boot, opens Simulator, builds unsigned into `build/`, installs, and launches `au.nearme.ios`. It exits before the macOS Team-file requirement. Updated usage and README with the iOS mode and branch-local testing commands.
  11. name check: clean
- Verify commands run and results:
  - `git diff --check`: passed. Git reports existing LF/CRLF conversion warnings, not whitespace errors.
  - `bash -n scripts/mac-run.sh` and Git Bash syntax checks of all CI run blocks: passed. The initial Python subprocess resolved Windows' unavailable WSL Bash; rerunning with the installed Git Bash executable passed. Embedded Xcode-selection Python compiled successfully.
  - Inline Python source-inventory/header/normalized-source comparisons and binary asset comparisons: passed for all 48 Swift files and 15 asset files. JSON assets, project/workflow YAML, and Info.plist parsed successfully; target/source isolation, required plist values, and preserved macOS configuration assertions passed.
  - Inline Python simulator fixtures: passed numeric runtime/model ordering, unavailable-device rejection, iPhone/iOS filtering, equivalent runtime versions, and empty inventories.
  - Mocked Git Bash execution of the iOS helper: passed fresh boot, already-booted launch, and failure propagation for an unrelated simulator boot error. The initial mock assertion expected captured boot output on stderr; correcting the mock's logging descriptor passed without changing application/helper code. These checks did not run an Apple build or simulator.
  - `git grep -n -i` checks of tracked files plus a direct scan of the untracked import: name check: clean. Secrets enum/example and legacy key-reference checks passed.
  - `Get-Command swift,xcodegen,xcodebuild -ErrorAction SilentlyContinue`: none available. This Windows machine has no Swift or Xcode. `swift test --package-path NearMeCore`, `xcodegen`, both task-specified `xcodebuild ... build` commands, and the new iOS test command could not be run. They are NOT reported as passing; GitHub CI is the compile gate.
- Mac test steps for the owner:
  1. On a Mac with Xcode containing the iOS 26.5 SDK or newer and an available iPhone runtime, select that Xcode under Settings > Locations > Command Line Tools. From this repository run `git checkout task/N10-ios-import`, `git pull --ff-only`, `brew install xcodegen`, `swift test --package-path NearMeCore`, and `xcodegen`.
  2. Run `xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`, then `xcodebuild -scheme NearMeiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`. Confirm both succeed.
  3. Run `UDID="$(xcrun simctl list devices available -j | python3 scripts/newest-iphone.py)"`, then `xcodebuild test -scheme NearMeiOS -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO`. Confirm all four supplied JourneyIntent tests pass and the hosted bundle loads.
  4. Before merge, build the branch with `xcodebuild -scheme NearMeiOS -configuration Debug -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build`. Run `xcrun simctl boot "$UDID"` (ignore only an already-booted result), `xcrun simctl bootstatus "$UDID" -b`, `open -a Simulator`, `xcrun simctl install "$UDID" build/Build/Products/Debug-iphonesimulator/NearMeiOS.app`, and `xcrun simctl launch "$UDID" au.nearme.ios`.
  5. Tap Continue, Start, then either screen-guidance choice. Grant microphone and speech access when requested; verify both system prompts say NearMe. With the ElevenLabs key empty, request a train journey from Box Hill to Melbourne Central, complete the simulated PTV steps, and check captions, speech, results, cancel/end-session, and return to onboarding. Repeat with the other screen-guidance choice; neither should start an actual broadcast. Speech capture may require a physical device if Simulator cannot supply it.
  6. After the manager merges N10 to main, use a fresh clone without either local xcconfig file, run `bash scripts/mac-run.sh ios`, and confirm install/launch. Run it again with the simulator already booted. Confirm CI for the final commit is green and lists the selected Xcode/runtime and successful iOS tests.
- Not done / risks / questions: Apple compilation, real permission prompts, voice capture, and walkthrough rendering remain unverified here. CI needs an installed SDK/runtime that supports the task's exact iOS 26.5 deployment target. Original app force unwraps and Swift 5 concurrency settings are retained under this task's explicit identical-behavior requirement. The supplied placeholder test file provides no keyword-parser coverage. The second product name mentioned in the brief was not present in the supplied iOS source snapshot; both new usage descriptions are exactly as specified. HIG notes arrived concurrently and were read: the imported fixed light appearance/palette, simulated permission wording, and existing controls/motion remain deliberate N10 preservation exceptions for N11b to address. No HIG redesign or other task work was performed.
- Commit blocked: `git add` succeeded and the staged scope contained only N10 files; `git diff --cached --check` and the tracked-file name check passed. `git commit -m "N10: import iOS prototype and add simulator build support"` then failed with `Unable to create .git/index.lock: Permission denied`. All N10 changes remain uncommitted, with this final report note unstaged. Per the user's explicit read-only-Git fallback, stopped here without appending an N10 LOG line; the manager must stage the updated report, commit, and append the LOG entry. The concurrent N11a commit/LOG entry is unrelated.
