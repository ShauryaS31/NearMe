#!/usr/bin/env bash
# NearMe Mac test helper.
# Usage: bash scripts/mac-run.sh [sim|quick|device|test|eval|report] [--current] [--device=NAME]
#   sim (default)  build for the newest iPhone simulator, boot it, install and launch
#   quick          incremental build of the current checkout; reuse a booted iPhone
#   device         build, install and launch on a connected iPhone (needs Config/Team.xcconfig)
#   test           run NearMeTests on the newest iPhone simulator
#   eval           run opt-in real-model journey, help-router and coach evaluations
#   report         write docs/mac-results/<timestamp>.md, then commit and push it
#   --current      build the checked-out branch without switching to main or pulling
#   --device=NAME  device mode: use this iPhone (name or id) when several are connected
set -euo pipefail
# Bash 4.4+ retains errexit inside command substitutions. macOS's Bash 3.2
# lacks this option, so simulator helpers also check each fallible command.
shopt -s inherit_errexit 2>/dev/null || true
SECONDS=0
cd "$(dirname "$0")/.."

mode="sim"; current=0; device_choice=""
for arg in "$@"; do
  case "$arg" in
    sim|quick|device|test|eval|report) mode="$arg" ;;
    --current) current=1 ;;
    --device=*) device_choice="$arg" ;;
    *) echo "Usage: bash scripts/mac-run.sh [sim|quick|device|test|eval|report] [--current] [--device=NAME]"; exit 1 ;;
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

if [[ "$mode" == "quick" ]]; then current=1; fi
# The Mac never edits code, so local changes to NearMe/Info.plist come from build
# tooling. Restore the committed copy so they cannot block the pull.
if [[ "$current" == 0 ]] && ! git diff --quiet -- NearMe/Info.plist; then
  echo "Restoring NearMe/Info.plist (changed locally by build tooling)."
  git checkout -- NearMe/Info.plist
fi
if [[ "$current" == 0 ]]; then git checkout main && git pull --ff-only; fi
[[ -f Secrets.xcconfig ]] || echo "No Secrets.xcconfig: ElevenLabs key is empty, so speech falls back to on-device Apple speech."
command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }
mkdir -p build
generation_hash="$(python3 - <<'PY'
import hashlib
from pathlib import Path

digest = hashlib.sha256()
digest.update(Path("project.yml").read_bytes())
for root in ("NearMe", "Shared", "NearMeLiveActivity", "NearMeBroadcastExtension", "NearMeTests"):
    for path in sorted(Path(root).rglob("*")):
        if path.is_file():
            digest.update(b"\0" + path.as_posix().encode("utf-8"))
print(digest.hexdigest())
PY
)"
previous_hash=""
if [[ -f build/.xcodegen-hash ]]; then previous_hash="$(cat build/.xcodegen-hash)"; fi
if [[ "$mode" != "quick" || ! -f NearMe.xcodeproj/project.pbxproj || "$generation_hash" != "$previous_hash" ]]; then
  xcodegen
  printf '%s\n' "$generation_hash" > build/.xcodegen-hash
fi

run_build() {
  # Full log in build/xcodebuild.log; show errors and the result line here.
  if ! xcodebuild "$@" > build/xcodebuild.log 2>&1; then
    grep -F "EVAL |" build/xcodebuild.log || true
    grep -E "error:|\*\* (BUILD|TEST) FAILED" build/xcodebuild.log | head -40 || true
    echo "Build failed. Full log: build/xcodebuild.log"; exit 1
  fi
  grep -F "EVAL |" build/xcodebuild.log || true
  grep -E "\*\* (BUILD|TEST) SUCCEEDED|Executed [0-9]+ tests?|Test run with" build/xcodebuild.log | tail -3 || true
}

newest_simulator() {
  local udid out
  udid="$(xcrun simctl list devices available -j | python3 scripts/newest-iphone.py)" || return 1
  [[ -n "$udid" ]] || { echo "No iPhone simulator id returned." >&2; return 1; }
  out="$(xcrun simctl boot "$udid" 2>&1)" || [[ "$out" == *"current state: Booted"* ]] || { echo "$out" >&2; return 1; }
  xcrun simctl bootstatus "$udid" -b > /dev/null || return 1
  open_device_ui
  echo "$udid"
}

quick_simulator() {
  local udid
  udid="$(xcrun simctl list devices available -j | python3 scripts/newest-iphone.py --booted)" || return 1
  if [[ -z "$udid" ]]; then
    newest_simulator || return 1
    return
  fi
  xcrun simctl bootstatus "$udid" -b > /dev/null || return 1
  open_device_ui
  echo "$udid"
}

open_device_ui() {
  # Xcode 27 replaced Simulator.app with DeviceHub.app. Opening the UI is optional;
  # the booted simulator keeps running either way. Keep stdout clean (it returns the UDID).
  open -a DeviceHub > /dev/null 2>&1 || open -a Simulator > /dev/null 2>&1 ||
    echo "Note: could not open DeviceHub or Simulator; the simulator is still booted." >&2
}

case "$mode" in
  sim|quick)
    if [[ "$mode" == "quick" ]]; then
      udid="$(quick_simulator)" || exit 1
    else
      udid="$(newest_simulator)" || exit 1
    fi
    [[ -n "$udid" ]] || { echo "No iPhone simulator id returned." >&2; exit 1; }
    run_build -scheme NearMe -configuration Debug -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
    xcrun simctl install "$udid" build/Build/Products/Debug-iphonesimulator/NearMe.app
    xcrun simctl launch "$udid" au.nearme.ios
    echo "NearMe launched on simulator $udid."
    ;;
  test)
    udid="$(newest_simulator)" || exit 1
    [[ -n "$udid" ]] || { echo "No iPhone simulator id returned." >&2; exit 1; }
    run_build -scheme NearMe -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
    ;;
  eval)
    udid="$(newest_simulator)" || exit 1
    [[ -n "$udid" ]] || { echo "No iPhone simulator id returned." >&2; exit 1; }
    TEST_RUNNER_NEARME_MODEL_EVAL=1 run_build -scheme NearMe -destination "id=$udid" -derivedDataPath build CODE_SIGNING_ALLOWED=NO test -only-testing:NearMeTests/ModelEvalTests
    ;;
  device)
    [[ -f Config/Team.xcconfig ]] || {
      echo "Copy Config/Team.xcconfig.example to Config/Team.xcconfig and set your Personal Team ID."; exit 1; }
    devices_json="$(mktemp)"; sims_json="$(mktemp)"
    xcrun devicectl list devices --json-output "$devices_json" > /dev/null
    # Simulator UDIDs let the helper reject simulators even if devicectl lists them.
    xcrun simctl list devices -j > "$sims_json" 2>/dev/null || echo '{}' > "$sims_json"
    device="$(python3 scripts/connected-iphone.py "$devices_json" "$sims_json" ${device_choice:+"$device_choice"})" || { rm -f "$devices_json" "$sims_json"; exit 1; }
    [[ -n "$device" ]] || { echo "No connected iPhone id returned." >&2; exit 1; }
    rm -f "$devices_json" "$sims_json"
    run_build -scheme NearMe -configuration Debug -destination "generic/platform=iOS" -derivedDataPath build -allowProvisioningUpdates build
    xcrun devicectl device install app --device "$device" build/Build/Products/Debug-iphoneos/NearMe.app
    xcrun devicectl device process launch --device "$device" au.nearme.ios
    echo "NearMe launched on the connected iPhone."
    ;;
esac
echo "Finished in ${SECONDS} seconds."
