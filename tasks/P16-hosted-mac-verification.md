# P16: Manual hosted Mac verification

## Authority and scope

The user explicitly authorized alternative native testing using existing hosted Mac resources while the local Windows machine has no Swift/Xcode. The existing GitHub workflow is manual-only; retain that trigger and contents-read permission. No purchases, billing limits, account permissions, secrets, signing or automatic push triggers may be changed. Root authorized one bounded hosted-runner attempt after reviewing this workflow change. Real iPhone/background/media/app-handoff acceptance remains separate.

## Acceptance criteria

1. Verify repository/workflow access and current primary-source runner compatibility; report unavailable allowance information without inventing remaining minutes.
2. Keep manual-only unsigned simulator build and hosted XCTest, explicitly select Xcode 26.5, bound execution to 30 minutes, and retain available native logs/xcresult artifacts even after failure.
3. Dispatch only after root review; report the actual run SHA, runner/compiler/runtime, build/test result and any concrete errors. Do not call source parsing compilation or mock tests native success.

## Inspection and preparation

- Inspected existing `.github/workflows/ci.yml` on remote main `20e6cc30e49a4242c33970506d9263d82c481f60`. It is active workflow ID 394739617, `workflow_dispatch` only, `macos-26`, unsigned build/test, contents-read permission.
- Existing authenticated repository owner account has ADMIN access and Actions are enabled. The connected GitHub plugin/default CLI account returned 404; read-only access succeeded with the owner's already-saved CLI credential supplied only through the child process environment. No token printed or account switched.
- Billing usage endpoint returned unavailable/404 and the CLI reported missing `user` scope. No scope refresh, billing change or purchase attempted. Remaining allowance is unknown; an actual dispatch may still be blocked by account policy/quota.
- Live primary runner list: https://raw.githubusercontent.com/actions/runner-images/main/images/macos/macos-26-Readme.md lists Xcode 26.5 and 26.6 with iOS 26.5 simulator SDK. Actual runner environment logs remain the authority for the dispatched job; no pre-run installed-runtime claim is made.
- Narrow workflow change: explicit `/Applications/Xcode_26.5.app` existence check and selection; OS/Xcode/Swift/SDK/runtime logs; 30-minute timeout; existing guide validator; unsigned build/test with result bundles and pipefail log capture; always-upload selected logs/result bundles for seven days. No private demo configuration is uploaded. A checkout without ignored Secrets.xcconfig selects public Apple-local defaults; cloud behavior is exercised only by mocked hosted unit tests, not live cloned-voice calls.

## Dev Report (round 1 — preparation; native outcome pending)

- Date: 2026-10-24 22:49 AEDT
- Changed files: `.github/workflows/ci.yml`; this task file.
- What I did: inspected existing workflow/access/resources and prepared the narrow manual-only hardening described above. Root owns review, commit, push and dispatch. No native run result is claimed in this preparation report.
- Acceptance criteria: 1 met with access/primary-source evidence and explicit unknown allowance; 2 implemented pending workflow execution; 3 pending actual dispatch/run evidence and follow-up report.
- Verify commands run and results: read-only `gh workflow view`, repository metadata, Actions permissions and remote main SHA succeeded using the saved owner account; billing usage read unavailable; local `git diff --check` PASS after preparation. No Swift/Xcode runs locally.
- Mac test steps for the owner:
  1. Review the delivered manual workflow and run link. Require environment logs to show the selected Xcode version and compatible simulator SDK/runtime; download xcresult/log artifacts and inspect actual build/test conclusions.
  2. On the owner's Mac, run `xcodebuild -version`, `xcrun swift --version`, `python3 scripts/validate-guides.py`, `bash scripts/mac-run.sh test --current`, then `bash scripts/mac-run.sh quick` against the same SHA. Do not commit the generated Xcode project.
  3. Transfer ignored private demo config separately and follow P14 physical-device gates with `bash scripts/mac-run.sh device --current`. Hosted unsigned simulator checks cannot verify provisioning, clone likeness/audio routing, ReplayKit capture of real YouTube, background widget recording, Island behavior or cross-app launch.
- Not done / risks / questions: actual dispatch/build/XCTest outcome pending root execution; no account allowance is inferred. No purchases, permissions changes, secrets or voice calls. If Xcode 26.5 is absent, fail clearly instead of silently compiling against a different SDK. Hosted runtime and artifact availability remain system-controlled.

## Dev Report (round 2 — hosted execution complete)

- Date: 2026-10-24 22:57 AEDT
- Changed files: this completion report and docs/LOG.md only. Application, tests and workflow are unchanged from the tested revision.
- What I did: reviewed and pushed the manual-only workflow, dispatched one run using the existing owner login, and monitored its actual native results. [Run 40091481419](https://github.com/ShauryaS31/NearMe/actions/runs/40091481419) tested commit `3ea0e9f5cadb8450c74ee97cfb3f19d632775c4f` and concluded SUCCESS. No rerun, purchase, permission change or live voice-service call was needed.
- Acceptance criteria:
  1. Met: existing repository access and runner allocation succeeded. Remaining account allowance is still unknown; no allowance amount is inferred from the successful run.
  2. Met: the manual workflow selected and logged Xcode 26.5, built without signing, executed hosted XCTest, and uploaded native results under its 30-minute cap. Actual job duration was 22:50:12–22:56:08 AEDT.
  3. Met: logs show macOS 26.6.2 (25G83), Xcode 26.5 (17F42), Apple Swift 6.3.2 compiler with project Swift 5 language mode, iOS 26.5 runtime (23F77), and an iPhone 17e simulator. The unsigned simulator build passed. XCTest reported 326 cases: 323 passed, 3 intentionally skipped, 0 failures, and TEST SUCCEEDED. The skips were ModelEvalTests requiring NEARME_MODEL_EVAL=1; no real-model evaluation success is claimed.
- Verify commands run and results: manual `gh workflow run ci.yml --repo ShauryaS31/NearMe --ref main` accepted; GitHub job and full-log inspection confirmed the native results above. Guide validation also passed. [Native artifact](https://github.com/ShauryaS31/NearMe/actions/runs/40091481419/artifacts/12559580992) contains available logs/result bundles, size 730,292 bytes, expiry 2026-10-31. Existing Swift concurrency/deprecation and AppIntents metadata warnings were nonfatal under retained Swift 5 mode; no warning-free or Swift 6 language-mode claim is made. Local Windows still has no Swift/Xcode; the successful native commands ran on GitHub's hosted Mac.
- Mac test steps for the owner:
  1. Pull the delivered main revision; inspect the linked native run/artifact. This follow-up changes only documentation relative to the tested SHA. For local reproduction run `python3 scripts/validate-guides.py`, `bash scripts/mac-run.sh test --current`, and `bash scripts/mac-run.sh quick` with Xcode 26.5 or compatible tooling.
  2. Transfer ignored Secrets.xcconfig privately for the personalized demo and configure signing/App Group. Run `bash scripts/mac-run.sh device --current` on the actual iPhone.
  3. Complete the P14 device gates: real YouTube launch and ReplayKit observation, frozen-feed handling, Island commands, cold/warm widget microphone sessions, actual silence/wait timers, media/interruption handling, audible personalized output and announced Apple recovery, largest text/VoiceOver/Reduce Motion. Simulator tests use fake voice/network services and cannot certify those behaviors.
- Not done / risks / questions: physical-device acceptance, real FoundationModels evaluation and personalized-cloud audio integration remain unverified. The earlier standalone voice endpoint smoke is separate evidence. Native build and hosted unit-test success are now verified; they do not establish always-on background operation, universal app control or an entirely offline demo.
