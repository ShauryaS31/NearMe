#!/usr/bin/env bash
# NearMe Mac test helper.
# Usage: bash scripts/mac-run.sh [sim|device|test|report] [--current]
#   sim (default)  build for the newest iPhone simulator, boot it, install and launch
#   device         build, install and launch on a connected iPhone (needs Config/Team.xcconfig)
#   test           run NearMeTests on the newest iPhone simulator
#   report         write docs/mac-results/<timestamp>.md, then commit and push it
#   --current      build the checked-out branch without switching to main or pulling
set -euo pipefail
cd "$(dirname "$0")/.."

mode="sim"; current=0
for arg in "$@"; do
  case "$arg" in
    sim|device|test|report) mode="$arg" ;;
    --current) current=1 ;;
    *) echo "Usage: bash scripts/mac-run.sh [sim|device|test|report] [--current]"; exit 1 ;;
  esac
done

if [[ "$mode" == "report" ]]; then
  mkdir -p docs/mac-results
  f="docs/mac-results/$(date +%Y-%m-%d-%H%M).md"
  {
    echo "# Mac results $(date '+%Y-%m-%d %H:%M %Z')"
    echo "- Commit: $(git rev-parse --short HEAD)"
    echo "- Machine: $(sysctl -n machdep.cpu.brand_string) | macOS $(sw_vers -productVersion) | $(xcodebuild -version | head -1)"
    echo
    echo "| Check | Result | Notes |"
    echo "|---|---|---|"
    echo "| | WORKS/BROKEN | |"
  } > "$f"
  ${EDITOR:-open -W -t} "$f"
  git pull --ff-only && git add "$f" && git commit -m "Mac results $(basename "$f" .md)" && git push
  echo "Pushed $f"; exit 0
fi

if [[ "$current" == 0 ]]; then git checkout main && git pull --ff-only; fi
[[ -f Secrets.xcconfig ]] || echo "No Secrets.xcconfig: ElevenLabs key is empty, so speech falls back to on-device Apple speech."
command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }
xcodegen
mkdir -p build

run_build() {
  # Full log in build/xcodebuild.log; show errors and the result line here.
  if ! xcodebuild "$@" > build/xcodebuild.log 2>&1; then
    grep -E "error:|\*\* (BUILD|TEST) FAILED" build/xcodebuild.log | head -40
    echo "Build failed. Full log: build/xcodebuild.log"; exit 1
  fi
  grep -E "\*\* (BUILD|TEST) SUCCEEDED|Executed [0-9]+ tests?|Test run with" build/xcodebuild.log | tail -3 || true
}

newest_simulator() {
  local udid out
  udid="$(xcrun simctl list devices available -j | python3 scripts/newest-iphone.py)"
  out="$(xcrun simctl boot "$udid" 2>&1)" || [[ "$out" == *"Booted"* ]] || { echo "$out" >&2; exit 1; }
  xcrun simctl bootstatus "$udid" -b > /dev/null
  open -a Simulator
  echo "$udid"
}

case "$mode" in
  sim)
    udid="$(newest_simulator)"
    run_build -scheme NearMe -configuration Debug -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
    xcrun simctl install "$udid" build/Build/Products/Debug-iphonesimulator/NearMe.app
    xcrun simctl launch "$udid" au.nearme.ios
    echo "NearMe launched on simulator $udid."
    ;;
  test)
    udid="$(newest_simulator)"
    run_build -scheme NearMe -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
    ;;
  device)
    [[ -f Config/Team.xcconfig ]] || {
      echo "Copy Config/Team.xcconfig.example to Config/Team.xcconfig and set your Personal Team ID."; exit 1; }
    devices_json="$(mktemp)"
    xcrun devicectl list devices --json-output "$devices_json" > /dev/null
    device="$(python3 scripts/connected-iphone.py "$devices_json")"
    rm -f "$devices_json"
    run_build -scheme NearMe -configuration Debug -destination "generic/platform=iOS" -derivedDataPath build -allowProvisioningUpdates build
    xcrun devicectl device install app --device "$device" build/Build/Products/Debug-iphoneos/NearMe.app
    xcrun devicectl device process launch --device "$device" au.nearme.ios
    echo "NearMe launched on the connected iPhone."
    ;;
esac
