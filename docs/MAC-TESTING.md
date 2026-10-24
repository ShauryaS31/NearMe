# Testing on the Mac

## One-time setup
1. Install Xcode (App Store), open it once to install components. Turn on Apple Intelligence in System Settings and let it download.
2. `xcode-select --install` if git is missing. Install Homebrew, then `brew install xcodegen gh`, then `gh auth login` (ShauryaS31).
3. `git clone https://github.com/ShauryaS31/NearMe.git ~/NearMe && cd ~/NearMe`
4. Copy `Secrets.xcconfig` from Windows (never via git). Copy `Config/Team.xcconfig.example` to `Config/Team.xcconfig` and set your Team ID (Xcode > Settings > Accounts > your Apple ID > Personal Team; the 10-character ID).

## Every test run
```
cd ~/NearMe && ./scripts/mac-run.sh
```
It pulls main, regenerates the project, builds and launches NearMe. First launch: System Settings > Privacy & Security > Accessibility > enable NearMe. If permission stops working after a rebuild, remove NearMe from the list and add it again.

## Reporting results
Run `./scripts/mac-run.sh report` to create `docs/mac-results/<timestamp>.md` with your machine details, fill in the checklist items you tested (PASS or FAIL, what you saw, latency), then it commits and pushes. Or just paste results to the manager on Windows.
