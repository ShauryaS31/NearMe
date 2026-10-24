# Log (append only)

Format: `- YYYY-MM-DD HH:MM AEDT | Task | actor | event | detail`

## Saturday 24 October 2026
- 2026-10-24 12:05 AEDT | - | claude (cowork) | decision | NearMe repo bootstrapped: spec, plan, rubric, factory, tasks N00 to N09, Mac test script. Windows codes, Mac tests
- 2026-10-24 12:27 AEDT | N00 | claude | dispatch r1 | brief tightened (optional xcconfig includes so CI builds without secrets); branch task/N00-scaffold
- 2026-10-24 12:30 AEDT | N00 | codex | dev-report r1 | Scaffold app, core package, optional signing/secrets, CI and Mac helper committed as efdf327; static checks passed; Swift/Xcode verification pending on Mac/CI.
- 2026-10-24 12:32 AEDT | N00 | claude | review r1 PASS | CI 40050142268 green; M1, M2 pending Mac; merged to main
- 2026-10-24 12:32 AEDT | N01 | claude | dispatch r1 | brief tightened (target last non-NearMe app, cap rule, tests, panel errors, no AX actions); branch task/N01-spike
- 2026-10-24 12:37 AEDT | N01 | codex | dev-report r1 | Implemented bounded AX reader, tool-free structured planner, validator, nonactivating ring and debug panel; committed as 84cda2c. Static checks passed; Swift/Xcode unavailable here; CI and Mac kill-rule result/latency pending.
- 2026-10-24 12:40 AEDT | N01 | claude | review r1 CHANGES | CI 40050658883 failed (NearMeCore CGRect import); 7 fixes incl. AX timeout race, AXEnabled default, static text labels; dispatch r2
- 2026-10-24 12:42 AEDT | N01 | codex | dev-report r2 | Addressed all seven round 1 fixes and both optional nits; committed abd8855. Static checks passed; Swift/Xcode unavailable; CI and Mac runtime gate pending.
- 2026-10-24 12:44 AEDT | N01 | claude | review r2 CHANGES | CI 40051038146 green; r1 fixes verified; owner request: multi-display coordinate tests; dispatch r3 (final)
- 2026-10-24 12:45 AEDT | N01 | codex | dev-report r3 | Moved unchanged coordinate conversion to its own file; added primary/above/left display tests; committed 6f8c19a. Static checks passed; Swift/Xcode unavailable; CI and Mac owner gate pending. Optional AX casts retained.
- 2026-10-24 12:48 AEDT | N01 | claude | review r3 PASS | CI 40051262605 green, 10 tests; merged to main; G1 kill-rule pending owner Mac checks M1 to M6
- 2026-10-24 13:38 AEDT | - | claude | decision | owner: prior prototype code reusable with permission, anonymised; CLAUDE.md, AGENTS.md, SPEC, MASTER-PLAN, README updated; N04a added; N03 next, N02 waits for G1
- 2026-10-24 13:38 AEDT | N03 | claude | dispatch r1 | brief tightened (PrivacyFilter API, exact bundle ids, whole-word title keywords, pipeline order, tests); branch task/N03-privacy
- 2026-10-24 13:41 AEDT | N03 | codex | dev-report r1 | Implemented pre-traversal privacy blocking, contact masking, label truncation and once-only local blocked speech; committed dbc2e33. Static checks passed; Swift/Xcode unavailable; seven new tests and Mac runtime checks pending CI/owner.
- 2026-10-24 13:50 AEDT | N03 | claude | review r1 PASS | CI 40055664698 green, 17 tests; merged to main; M7 pending Mac
- 2026-10-24 13:53 AEDT | - | claude | history rewrite | owner-authorised: filter-repo replace-text removed prior project names from all commits; log -p verified clean; Secrets.xcconfig never in history; main and task branches force-pushed; old CI runs deleted; going public on hold (Activity feed keeps old SHAs)
- 2026-10-24 13:53 AEDT | - | claude | decision | owner: import prior iOS prototype as second target NearMeiOS (N10, before N04a)
- 2026-10-24 14:04 AEDT | - | claude | decision | owner: PIVOT to iPhone; macOS main archived to archive/mac-nearme (04a69d2); repo stays private (recreate deferred); CI manual only
- 2026-10-24 14:04 AEDT | N10 | codex | dev-report r1 | iOS prototype imported (48 Swift, 15 assets, name check clean); committed by manager (sandbox blocked .git)
- 2026-10-24 14:04 AEDT | P01 | claude | import | N10 tree moved to repo root as NearMe/Shared/NearMeBroadcastExtension/NearMeTests; macOS code and tasks N00 to N11 removed; project.yml, mac-run.sh (sim, device, test, report), manual CI, SPEC v2, PLAN rewritten; names clean; Mac pending (P02)
- 2026-10-24 14:15 AEDT | P01 | owner | mac gate PASS | Xcode 27.1, iOS 27.1 sim (iPhone Duo): 4/4 JourneyIntent tests pass; P01 done
- 2026-10-24 14:15 AEDT | P01 | claude | fix | Simulator.app gone in Xcode 27 (DeviceHub.app): mac-run.sh opens DeviceHub else Simulator, never fails; MAC-TESTING.md updated to Xcode 27.1 / iOS 27.1 / DeviceHub
- 2026-10-24 14:41 AEDT | P02 | owner | baseline | simulator iOS 27: full flow works; mic works after macOS mic permission for DeviceHub; bugs: from-to parsing, raw follow-up answers, invented facts; needs debug badge, real errors, Type instead
- 2026-10-24 14:41 AEDT | P02a | claude | dispatch r1 | brain source badge, os Logger voice, Type instead, keyword backstop and tests for both brains, follow-up place extraction, remove invented facts; branch task/P02a-debug-parsing-facts
