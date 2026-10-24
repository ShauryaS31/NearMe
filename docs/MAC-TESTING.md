# Testing on the Mac (iPhone app)

## One-time setup
1. Install Xcode 27.1 (App Store; the version tested) and open it once. In Xcode > Settings > Components, install the iOS 27.1 platform and simulator runtime (the app's minimum is iOS 26.5). Turn on Apple Intelligence on the Mac so Foundation Models works in the simulator.
2. Install Homebrew, then `brew install xcodegen gh`, then `gh auth login` (account ShauryaS31; the repo is private).
3. `git clone https://github.com/ShauryaS31/NearMe.git ~/NearMe && cd ~/NearMe`. If you cloned before the history rewrite, delete that folder and clone again.
4. Optional: copy `Secrets.xcconfig` from Windows (never via git) for the ElevenLabs key. Without it, speech uses on-device Apple speech.
5. For a real iPhone only: `cp Config/Team.xcconfig.example Config/Team.xcconfig` and set `DEVELOPMENT_TEAM` to your 10-character Personal Team ID (Xcode > Settings > Accounts > your Apple ID). On the iPhone: Settings > Privacy & Security > Developer Mode on (restart), and turn on Apple Intelligence.

## Every test run
```
cd ~/NearMe
bash scripts/mac-run.sh          # newest iPhone simulator: build, boot, install, launch
bash scripts/mac-run.sh test     # NearMeTests on the simulator
bash scripts/mac-run.sh device   # connected iPhone (cable, unlocked, Trust this computer)
```
Add `--current` to test a task branch you have checked out. Build output is in `build/xcodebuild.log`; errors are printed on failure.

Tested with Xcode 27.1 and the iOS 27.1 simulator ("iPhone Duo"). Xcode 27 replaced Simulator.app with DeviceHub.app: the script opens DeviceHub if present, otherwise Simulator, and carries on if neither opens (the simulator stays booted).

First run on an iPhone with a Personal Team: if launch fails with an untrusted developer message, open Settings > General > VPN & Device Management on the iPhone, trust your Apple Development certificate, then run `bash scripts/mac-run.sh device` again. If signing fails, open the generated `NearMe.xcodeproj`, choose your team under the NearMe target's Signing & Capabilities, build once, and re-run.

## Reporting results
Run `bash scripts/mac-run.sh report` to create `docs/mac-results/<timestamp>.md` with your machine details, fill in each check (WORKS or BROKEN, what you saw), then it commits and pushes. Or paste results to the manager on Windows.
