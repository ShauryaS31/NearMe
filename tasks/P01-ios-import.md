# P01: Import the prior iPhone prototype as NearMe

| Field | Value |
|---|---|
| Status | in_review (Mac pending, checked in P02) |
| Window | Sat 24 Oct, pivot |
| Depends on | - |
| Assignee | codex (import, as N10 on archive branch task/N10-ios-import), manager (move to repo root, build setup) |
| Branch | task/P01-ios-import |

## Goal
Start the iPhone plan from the prior prototype (used with permission), imported exactly: same files and behaviour, only renaming and build setup changed.

## Acceptance criteria
- [x] App sources, Shared, broadcast extension source and tests imported, same structure: `NearMe/`, `Shared/`, `NearMeBroadcastExtension/`, `NearMeTests/`. No .xcodeproj, xcuserdata, .DS_Store or .bak files
- [x] Old product names renamed to NearMe in types, files, strings, display name and permission prompts; logic unchanged (the default greeting name is now "Friend" because the original used a person's name)
- [x] Every Swift file starts with `// Adapted from a prior prototype, used with permission.`; original headers and person names removed
- [x] Keys: `APIKeys` reads `ELEVENLABS_API_KEY` from Info.plist, filled from gitignored `Secrets.xcconfig` via `Config/Base.xcconfig`; no Secrets.swift, no keys in git
- [x] project.yml: `NearMe` iOS 26.5 app (`au.nearme.ios`, team from `Config/Team.xcconfig`) and hosted `NearMeTests`; broadcast extension not a target
- [x] `scripts/mac-run.sh`: default simulator mode, `device`, `test`, `report`, `--current`
- [x] CI manual only (workflow_dispatch)
- [x] `git grep` finds no old project name or author name
- [ ] PENDING MAC: builds, tests pass, launches in simulator and on iPhone (P02)

## Review (round 1)
- Date: 2026-10-24 14:02 AEDT
- Verdict: PASS for the import (static); runtime is P02.
- N10 round 1 Dev Report: 48 Swift and 15 asset files imported, inventory and normalised-source comparison against the originals passed, assets byte-identical, name check clean. Manager moved the tree to the repo root, renamed module `NearMeiOS` to `NearMe` (one `@testable import`), rewrote project.yml, mac-run.sh and CI.
- Known: never compiled yet (CI is manual, Mac is the gate). The original test files were never part of a target; `KeywordFallbackBrainTests.swift` contains only an import, so NearMeTests runs the 4 JourneyIntent tests.
