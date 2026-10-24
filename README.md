# NearMe

Digital independence, with a familiar voice. A macOS companion that reads the buttons on the screen you're looking at, works out the next step on device, points at it and says it out loud.

Built at AI On Apple, Sydney, 24 to 25 October 2026.

- Spec: [docs/SPEC.md](docs/SPEC.md) | Plan: [docs/PLAN.md](docs/PLAN.md) | Rubric: [docs/RUBRIC.md](docs/RUBRIC.md)
- Agent factory: [docs/FACTORY.md](docs/FACTORY.md) | Testing on the Mac: [docs/MAC-TESTING.md](docs/MAC-TESTING.md)

## Mac setup

Use macOS 26 or later and Xcode 26 or later. Open Xcode once to install its components, select it under Xcode > Settings > Locations > Command Line Tools, and add your Apple ID under Settings > Accounts. Foundation Models availability also depends on Apple Intelligence being enabled and its model being downloaded on an eligible Mac; the placeholder window shows the actual status.

From the repository root:

```bash
brew install xcodegen
cp -n Secrets.xcconfig.example Secrets.xcconfig
cp -n Config/Team.xcconfig.example Config/Team.xcconfig
```

Set `DEVELOPMENT_TEAM` in `Config/Team.xcconfig` to your Personal Team's 10-character ID. Keep the signing settings from the example. If you already have a team file containing only the ID, add the example's three signing settings. You can copy your existing `Secrets.xcconfig` securely from Windows, or fill in the example's optional keys locally. Empty keys are fine for the scaffold. Both local files are gitignored; never commit them.

```bash
bash scripts/mac-run.sh
```

The helper pulls `main`, tests NearMeCore, generates the Xcode project, builds and launches `build/Build/Products/Debug/NearMe.app`. To test the branch you have checked out without pulling or switching branches, use `bash scripts/mac-run.sh --current`. If Xcode needs to create an Apple Development signing certificate, open the generated `NearMe.xcodeproj`, select the NearMe target's Signing & Capabilities, choose your Personal Team, and build once.

The window shows Accessibility trust, Foundation Models availability and the macOS version. To grant Accessibility access, open System Settings > Privacy & Security > Accessibility, add the built app with the `+` button and enable it. Return to NearMe to refresh its status. Keep the same signing team and build path for subsequent runs so the permission can persist. The scaffold does not request microphone or speech access yet.

To create a Mac results report, run `bash scripts/mac-run.sh report`; this existing helper opens a report for editing, then commits and pushes it.

For the iOS prototype, install Xcode with an iOS 26.5 or newer SDK and an available iPhone simulator runtime (Xcode > Settings > Components), then run:

```bash
bash scripts/mac-run.sh ios
```

This mode checks out and pulls `main`, generates the project, boots the newest available iPhone on the highest installed iOS runtime, opens Simulator, and builds, installs and launches NearMe. It requires neither `Config/Team.xcconfig` nor `Secrets.xcconfig`. Without an ElevenLabs key, speech input uses the original Apple fallback. The iOS prototype retains its simulated guided PTV walkthrough; the broadcast extension source is included for reference but is not built.

To test a task branch's iOS app without switching branches, run:

```bash
xcodegen
UDID="$(xcrun simctl list devices available -j | python3 scripts/newest-iphone.py)"
xcodebuild test -scheme NearMeiOS -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO
```

## Build without local configuration

Neither local configuration file is needed to test or build. `Config/Base.xcconfig` defaults to unsigned builds and empty service keys, then optionally includes the local files. The Team example enables signing for Mac launch tests.

```bash
swift test --package-path NearMeCore
xcodegen
xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

CI runs these checks on `macos-26`. `NearMe.xcodeproj` is generated and gitignored. NearMeCore uses Swift 6 and contains only pure logic; the app target owns the platform frameworks. App Sandbox is disabled and hardened runtime is enabled. Swift and Xcode are unavailable on the Windows development machine; GitHub CI is the compile gate.

CI also selects the newest installed Xcode, prints its version and simulator runtimes, builds the `NearMeiOS` scheme, and runs the hosted `NearMeiOSTests` on the newest available iPhone simulator. The imported iOS target retains Swift 5 mode and MainActor default isolation.

## Prior work

Adapted from a prior prototype, used with permission.
