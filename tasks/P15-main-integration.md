# P15: Preserve old main and integrate completed development

## Authority and scope

The user explicitly requested: push all completed changes to main after checking, preserve old main in a separate branch, and assign a separate integration subagent. This instruction overrides the normal no-merge rule for this task. Preserve newer main work and development functionality with a normal merge; never force push. Keep private voice configuration, recordings and unrelated mockups out of Git.

## Acceptance criteria

1. Preserve and verify the exact original remote main tip in a separately pushed backup branch before changing main.
2. Integrate completed development and newer main history without discarding the approved P09 UI or the newer YouTube/widget/voice behavior.
3. Review conflicts, run available checks, document native test limitations and verify a normal main push and the unchanged backup.

## Dev Report (round 1)

- Date: 2026-10-24 22:42 AEDT
- Changed files: normal merge brings the completed changes listed in P04c, P05a, P10a, P13d and P14 into main. Integration-specific resolutions affect AppCoordinator.swift, ContentView.swift, Info.plist, HandsFreeVoiceCommands.swift, NearMeAudioSession.swift, OnDeviceCommandSpeechInput.swift, VoiceCommand.swift, TaskPlannerEngine.swift, CoachView.swift, SessionContainerView.swift, HandsFreeVoiceCommandTests.swift, ScreenCoachIntegrationTests.swift and docs/LOG.md. Additional integration edits: VoiceSessionMenu.swift, VoiceSessionView.swift, AskNearMeTests.swift, UIPolishTests.swift and this task file. Corrected the P14 log timestamp to its actual 22:41 AEDT commit time.
- What I did: fetched origin and verified original main `c158d003a9beb484d2912eaeafcf6a766359ec42`. Created and pushed `codex/backup-main-20261024-223826`, then verified its remote tip exactly equals the unchanged main. Prepared a normal two-parent merge in isolated `build/main-integration`, combining main with completed development `aa03eed14459cb16e76f57350df218b0e2e48eb5`.
- Conflict resolution: main's P13c speech/engine baseline was byte-identical to development's inherited checkpoint f0f4f53, so retained development's subsequent behavior on that proven identical baseline. Preserved main's extra wait-until-idle assertion. Retained the complete P09 plum assets, orb home, route presentation, Reduce Motion behavior, onboarding views, coach help sheet and controls, UI tests, SPEC/PLAN/CLAUDE/AGENTS and prior logs. Combined shared-engine/widget handoff with main's ordinary orb launch and prewarm, without automatic guide restoration. Added the widget setup sheet to the existing More menu. Migrated prior `hasCompletedOnboarding` completion to the widget completion key; explicit completion and restart update both, and opening a setup link cannot itself complete onboarding. Added two focused regressions and isolated the older onboarding test from persistent standard defaults.
- Acceptance criteria:
  1. Met: backup was verified remotely before merge preparation. Initial automatic approval rejection was resolved by proving the new reference points only to history already on the same configured origin and restating the user's explicit instruction; no protection was bypassed.
  2. Met in the reviewed candidate: main and completed development remain merge parents; semantic resolutions preserve both sets of behavior. Independent root and verification reviewers found no blocking merge defect before commit/push. Root additionally checked seven merged Swift UI/coordinator files grammar-clean.
  3. Available checks completed below; final remote verification is recorded in the completion entry after the authorized push.
- Verify commands run and results:
  - `git fetch origin`, `git ls-remote origin refs/heads/main refs/heads/codex/backup-main-20261024-223826`: fetched and confirmed both tips equal the preserved original commit before integration.
  - `git diff --check`: PASS. Conflict-marker scan: none in candidate source/tests/log.
  - `python scripts/validate-guides.py`: PASS, 16 guides, 0 problems.
  - Python tree-sitter Swift grammar inspection: 113 Swift files; five raw-parser diagnostic files, all also diagnostic in original main (TaskPlannerEngine, VoiceSessionMenu, CoachActivityAttributes, CoachAppOpenTests, ScreenObservationTests). This is not Swift compilation, actor checking or XCTest execution.
  - Python plistlib/json: candidate plist, entitlement and asset JSON files parse. project.yml manually checked for retained iOS 26.5, Swift 5, MainActor and inherited extension wiring. PyYAML is unavailable; no YAML/XcodeGen execution claimed.
  - Private API-key and voice-ID values were compared against every tracked candidate file without printing them: absent. Secrets.xcconfig remains untracked/ignored; no generated project or new audio is included. Unrelated root docs/ui-mockups are untouched.
  - Root previously executed all 12 unchanged Python tooling tests successfully, using mocked Apple tools. No repetition was needed because integration does not change those scripts.
  - This Windows machine has no Swift or Xcode. No native build, XCTest, simulator or physical iPhone test ran.
- Mac test steps for the owner:
  1. In the owner's clean checkout, run `git fetch origin`, `git switch main`, `git pull --ff-only origin main`, and `git rev-parse HEAD`. Transfer ignored Secrets.xcconfig privately if the personalized demo build is wanted; Git alone retains the Apple-voice default.
  2. Run `python3 scripts/validate-guides.py`, `bash scripts/mac-run.sh test --current`, then `bash scripts/mac-run.sh quick`. Require hosted XCTest success, especially AskNearMeTests, UIPolishTests, ScreenCoachIntegrationTests, HandsFreeVoiceCommandTests, NearMeVoiceOutputTests and ElevenLabsVoiceOutputTests. Save native logs; do not commit the generated project.
  3. Configure signing/App Group for the app and both extensions. Connect a trusted Developer Mode iPhone and run `bash scripts/mac-run.sh device --current`. Verify first launch and returning launch, plum orb home, More > Set up Ask NearMe, widget setup deep links, prior onboarding migration and explicit restart.
  4. Follow the exact physical-device checks in P14: real YouTube opening/sharing/observed steps, Island bounded listening, widget cold/warm capture and follow-ups, silence/wait/Stop, interruptions/media, personalized output and explicitly announced Apple fallback. Check VoiceOver, largest text and Reduce Motion on preserved P09 UI.
- Not done / risks / questions: native compilation and all audio/background/device gates remain pending. Syntax/configuration/source checks do not establish those behaviors. Demo spoken reply text goes to ElevenLabs; private configuration and approved audio must never be committed. No force push, reset, history rewrite or branch-protection bypass is authorized or performed.
