#!/usr/bin/env bash
# NearMe Mac test helper. Usage: ./scripts/mac-run.sh [report]
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == "report" ]]; then
  mkdir -p docs/mac-results
  f="docs/mac-results/$(date +%Y-%m-%d-%H%M).md"
  {
    echo "# Mac results $(date '+%Y-%m-%d %H:%M %Z')"
    echo "- Commit: $(git rev-parse --short HEAD)"
    echo "- Machine: $(sysctl -n machdep.cpu.brand_string) | macOS $(sw_vers -productVersion) | $(xcodebuild -version | head -1)"
    echo
    echo "| Check | Result | Notes |"
    echo "|---|---|---|"
    echo "| | PASS/FAIL | |"
  } > "$f"
  ${EDITOR:-open -W -t} "$f"
  git pull --ff-only && git add "$f" && git commit -m "Mac results $(basename "$f" .md)" && git push
  echo "Pushed $f"; exit 0
fi
git checkout main && git pull --ff-only
[[ -f Secrets.xcconfig ]] || { echo "Missing Secrets.xcconfig (copy it from Windows)"; exit 1; }
xcodegen
xcodebuild -scheme NearMe -configuration Debug -destination 'platform=macOS' -derivedDataPath build build | tail -5
pkill -x NearMe 2>/dev/null || true
open build/Build/Products/Debug/NearMe.app
echo "NearMe launched from build/Build/Products/Debug (keep this path so Accessibility permission sticks)."
