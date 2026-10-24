# N00: Scaffold NearMe repo: XcodeGen, NearMeCore, CI, Mac run script

| Field | Value |
|---|---|
| Status | done |
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
- [ ] A committed `Config/Base.xcconfig` pulls in the gitignored files with optional includes (`#include? "../Secrets.xcconfig"`, `#include? "Team.xcconfig"`) so CI and a fresh clone build with neither file present (keys empty, unsigned)
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

## Dev Report (round 1)
- Date: 2026-10-24 12:30 AEDT
- Changed files: `project.yml`; `Config/Base.xcconfig`; `Config/Team.xcconfig.example`; `NearMeCore/Package.swift`; `NearMeCore/Sources/NearMeCore/Scaffold.swift`; `NearMeCore/Tests/NearMeCoreTests/ScaffoldTests.swift`; `NearMe/NearMeApp.swift`; `NearMe/ContentView.swift`; `NearMe/Info.plist`; `.github/workflows/ci.yml`; `scripts/mac-run.sh`; `README.md`; this task file. `docs/LOG.md` receives the requested handoff entry after the commit attempt.
- What I did: Created the empty native SwiftUI app and linked the local pure Swift package. Added optional local configuration with unsigned/empty defaults, Personal Team signing overrides, status display, CI, and Mac setup instructions. Preserved the helper's main-branch update and report modes, added `--current` for task-branch testing, ran core tests before app builds, and made secrets optional. Existing local secrets were not read or modified. No later-task functionality was implemented.
- Acceptance criteria:
  1. XcodeGen: `project.yml` defines the NearMe macOS 26 application and shared NearMe scheme, `au.nearme.app`, Swift 6 strict concurrency, sandbox disabled and hardened runtime enabled. Debug and Release use Base.xcconfig; the optional Team file supplies DEVELOPMENT_TEAM and signing overrides. The existing gitignore already excludes generated Xcode projects. Mac generation/build and signing remain unverified here.
  2. Core package: tools version 6.0, `.macOS("26.0")` (compatible with the 6.0 manifest API), one public placeholder namespace and one Swift Testing test. No platform-framework imports; the app displays the placeholder message to exercise package linkage.
  3. Secrets: the existing gitignored Secrets.xcconfig is optionally included; the three requested Info.plist keys expand their matching build settings. The existing committed secrets example remains suitable.
  4. Base configuration: both exact optional include paths are present, after empty key defaults and CODE_SIGNING_ALLOWED=NO. The Team example opts into Apple Development automatic signing. Missing local files do not prevent project generation by design; CI is the pending build verification.
  5. Privacy strings: both microphone and speech-recognition usage descriptions are in Info.plist and describe NearMe's intended voice input.
  6. Placeholder window: shows Yes/No Accessibility trust, Foundation Models availability including unavailable reasons, and the OS version; refreshes on scene-phase changes. Trust is checked off the main thread with a one-second wait budget and ignored late results. No AX tree is read and no permission is requested automatically. Launch behavior requires the Mac check below.
  7. CI: push and pull-request workflow uses macos-26; runs the exact core test command, installs XcodeGen, generates the project, then runs the requested unsigned xcodebuild command. No remote workflow was triggered from this workspace.
  8. Mac helper: retained the stable build/Build/Products/Debug/NearMe.app path and report mode. Signed launch requires the local Team file; core tests precede generation/build; secrets are optional. Bash syntax passes. End-to-end execution needs macOS.
  9. README: documents Xcode/macOS prerequisites, brew install xcodegen, copying both example configurations, Personal Team setup, default and current-branch helper invocations, trust checking, and unsigned builds without local files.
- Verify commands run and results:
  - `git diff --check`: passed before this report.
  - `bash -n scripts/mac-run.sh`: passed.
  - Python stdin checks using plistlib and PyYAML: passed Info.plist parsing/substitutions/privacy strings; project YAML target/platform/signing flags/config references/package linkage; CI runner/command order; core import boundary; optional include paths; shell LF line endings. These are static checks, not XcodeGen or Swift validation. An earlier inline Python command failed due to PowerShell quoting; the stdin rerun passed.
  - `git check-ignore` confirmed both private config files, generated project contents, app build outputs and package build outputs are ignored.
  - `Get-Command swift,xcodegen,xcodebuild -ErrorAction SilentlyContinue` found none. This Windows machine has no Swift or Xcode (nor XcodeGen). `swift test --package-path NearMeCore` and `xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` were NOT run and are NOT claimed to pass. GitHub CI is the compile gate.
- Mac test steps for the owner:
  1. Use a Mac with macOS 26+ and Xcode 26+; open Xcode once, install components and select it under Settings > Locations > Command Line Tools. Run `brew install xcodegen`.
  2. After the manager commits/pushes this task branch, test a clean checkout with no local configuration: `check_dir=$(mktemp -d)` then `git clone --branch task/N00-scaffold https://github.com/ShauryaS31/NearMe.git "$check_dir"` then `cd "$check_dir"`. Run `swift test --package-path NearMeCore`, `xcodegen`, and `xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`. Expect the placeholder test and unsigned build to pass with neither private file present. Check the GitHub CI run as well.
  3. In the owner's normal checkout, run `cd ~/NearMe`, check out the committed task branch, and run `cp -n Secrets.xcconfig.example Secrets.xcconfig` and `cp -n Config/Team.xcconfig.example Config/Team.xcconfig`. Set the actual Personal Team ID and keep all three signing settings from the example; leave optional service keys blank for this check. Add the Apple ID in Xcode Settings > Accounts. If needed, generate/open the project and build once in Xcode to create the development signing certificate.
  4. Run `bash scripts/mac-run.sh --current`. Expect core tests/build to pass and a NearMe window with the placeholder message, Accessibility Yes/No, a meaningful Foundation Models status, and the correct macOS version.
  5. In System Settings > Privacy & Security > Accessibility, use `+` to add `~/NearMe/build/Build/Products/Debug/NearMe.app` and enable it. Return to NearMe and expect Yes. Disable the permission and return to expect No, then enable again. Check that unavailable Apple Intelligence produces a status message rather than a crash.
  6. Run `bash scripts/mac-run.sh --current` again with the same team and path; expect Accessibility to remain Yes. Run `codesign -dv --verbose=4 build/Build/Products/Debug/NearMe.app` and confirm the expected TeamIdentifier and runtime flag. Inspect the target's build settings in Xcode to confirm App Sandbox is No and Hardened Runtime is Yes.
  7. Record results with `bash scripts/mac-run.sh report` when ready to commit/push the report, or send them to the manager. After merge, the normal `bash scripts/mac-run.sh` command updates main and performs the same checks/build/launch.
- Not done / risks / questions: No compilation, model availability, code-signing, TCC persistence or UI launch claims can be made on Windows. A cancelled native trust call cannot be forcibly interrupted; the UI stops awaiting it at the deadline. No planner, AX reader, overlay or speech implementation belongs to N00. Git accepted staging despite the advertised read-only sandbox restriction; the script's executable mode was staged as 100755 for compatibility with the existing Mac testing guide's direct invocation. README also supports explicit `bash` invocation. Technical references checked: [XcodeGen project specification](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md), [Swift PackageDescription platform string support](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html), and [Apple SystemLanguageModel availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel).

## Review (round 1)
- Date: 2026-10-24 12:32 AEDT
- Verdict: PASS
- CI run 40050142268 green on macos-26: NearMeCore 1 test passed, `xcodegen` ok, `xcodebuild` BUILD SUCCEEDED with no compiler warnings.
- Criteria: project.yml (sandbox off, hardened runtime on, bundle id, Team via xcconfig) met; NearMeCore has no platform imports; Base.xcconfig optional includes let CI build with no local files; Info.plist keys and usage strings present; CI workflow matches brief; mac-run.sh kept working (adds `--current` and a Team.xcconfig check); README Mac setup present; no secrets in diff.
- PENDING MAC: placeholder window shows the three statuses; build is signed with the Personal Team (XcodeGen presets could override `CODE_SIGN_IDENTITY`) so Accessibility permission survives a rebuild. Steps in PLAN.md Mac gate checklist (M1, M2).
