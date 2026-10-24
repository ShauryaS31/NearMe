# P02b: Onboarding at large text sizes, honest explainer copy

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct, after P02a, before P03 |
| Depends on | P02c |
| Assignee | codex |
| Branch | task/P02b-onboarding-text-copy |

## Goal
Onboarding must work for older users at the largest accessibility text sizes (found in the large-text test), and the explainer must say honestly what NearMe does: it does not watch other apps.

## Read
AGENTS.md; docs/design/HIG-NOTES.md rules 2, 3, 7, 11, 12 and 13. Files: `NearMe/Views/Onboarding/WelcomeView.swift`, `GoodMorningView.swift`, `ScreenPermissionView.swift`, `NearMe/Views/Components/ScreenScaffold.swift`, `NearMe/Views/Components/Theme.swift`, `NearMe/App/AppCoordinator.swift`, `NearMe/App/ContentView.swift`, `NearMe/Models/AppRoute.swift`.

## Acceptance criteria
### 5. Largest accessibility text sizes
- [ ] Every onboarding screen (welcome, greeting, explainer) scrolls vertically: all content and the primary button are reachable at Accessibility XXXL (`.accessibility5`) on the smallest current iPhone simulator
- [ ] Safe areas respected: no text or control under the Dynamic Island, status bar or home indicator. Only background colours may use `ignoresSafeArea`
- [ ] Text uses Dynamic Type text styles only (`.largeTitle`, `.title`, `.title2`, `.headline`, `.body`, `.callout`, `.footnote`, or the `TTFont` helpers that wrap them). No `.font(.system(size:))` for text in these screens; decorative SF Symbols scale with `@ScaledMetric` or a text style
- [ ] No fixed heights on text containers: remove `.frame(minHeight: 480)` and fixed `height:` on anything that holds text. Fixed sizes remain only for decorative icons, and those use `@ScaledMetric`
- [ ] Text never truncates or shrinks (`lineLimit(nil)`, no `minimumScaleFactor`); horizontal rows (for example the "Near Me" wordmark) stack vertically at accessibility sizes (`dynamicTypeSize.isAccessibilitySize`)
- [ ] `#Preview`s for each onboarding screen at `.accessibility5` and default size

### 6. Honest explainer
- [ ] Explainer copy is exactly: "NearMe shows you practice copies of everyday apps, so you can learn safely. It never looks at your other apps."
- [ ] The screen-permission step becomes an explainer, not a permission request: heading "How NearMe works" (or similar plain heading), one primary "continue" button, no "allow" / "don't allow". Rename `ScreenPermissionView` to `HowItWorksView`, the route `.screenPermission` to `.howItWorks`, and replace `resolveScreenPermission(granted:)` with a plain advance. Remove `didGrantScreenGuidancePermission` (set but never read)
- [ ] No other screen or spoken line claims NearMe watches, sees or reads the screen or other apps (`git grep -n -i -E "see your screen|watch(es|ing)? (what|your)|on screen while"` over `NearMe/` returns nothing)

### 7. Faster Mac runs: `quick` mode in scripts/mac-run.sh
- [ ] `bash scripts/mac-run.sh quick`: no git checkout or pull (builds whatever is checked out); runs `xcodegen` only when `project.yml` or the list of files under `NearMe/`, `Shared/` and `NearMeTests/` changed since the last generation (store a hash in `build/.xcodegen-hash`); reuses the already booted simulator (boots only if none is booted); incremental build into `build/` (no clean); install and launch. Prints the elapsed seconds at the end
- [ ] Usage line, README table and docs/MAC-TESTING.md list `quick`
- [ ] Fix: if picking or booting the simulator fails, every mode stops with the error instead of continuing with an empty device id (command substitution does not inherit `set -e`: use `shopt -s inherit_errexit` and check the id is non-empty)

## Verify (Mac)
```
bash scripts/mac-run.sh --current
```
Then in the simulator: Settings > Accessibility > Display & Text Size > Larger Text > on, slider to maximum; walk all three onboarding screens.

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)
- Date: 2026-10-24 15:21 AEDT
- Changed files: `NearMe/Views/Onboarding/WelcomeView.swift`, `GoodMorningView.swift`, `ScreenPermissionView.swift` (renamed to `HowItWorksView.swift`); `NearMe/Views/Components/PrimaryButton.swift`; `NearMe/App/AppCoordinator.swift`, `ContentView.swift`; `NearMe/Models/AppRoute.swift`, `TaksPlannerState.swift`; `scripts/mac-run.sh`, `scripts/newest-iphone.py`, `scripts/tests/test_mac_run.py`; `README.md`; `docs/MAC-TESTING.md`; this task file.
- What I did: Put all three onboarding screens and their primary actions inside the existing scrolling scaffold; removed the 480-point minimum heights, enabled natural text wrapping, scaled decorative icons, and stacked the welcome wordmark at accessibility sizes. Replaced the fake permission request with the exact practice-app explanation and a plain advance to the session. Added cached project generation and booted-iPhone reuse for `quick`, explicit simulator failure propagation, and isolated command-mock regression checks. Reworded a planner-state comment that accidentally matched the required copy grep. Left the shared scaffold, theme and build settings unchanged.
- Acceptance criteria:
  - 5, vertical scrolling: welcome, greeting and explainer all use `ScreenScaffold`'s vertical `ScrollView`, with primary buttons inside its content. Natural vertical sizing avoids text compression. Smallest-iPhone runtime reachability remains for the Mac gate.
  - 5, safe areas: onboarding content does not ignore safe areas; only the scaffold's background color does. Runtime checks around the status bar, Dynamic Island and home indicator remain for the Mac gate.
  - 5, Dynamic Type: all onboarding text uses semantic `TTFont` styles. Decorative symbols use a semantic font or `@ScaledMetric`; icon background dimensions scale too.
  - 5, heights: removed both `.frame(minHeight: 480)` modifiers. No text container has a fixed height; decorative icon dimensions use `@ScaledMetric`. The button's minimum tap target remains a floor, not a fixed height.
  - 5, no truncation/shrinking: onboarding applies `.lineLimit(nil)` and natural vertical sizing; `PrimaryButton` no longer limits lines or uses `minimumScaleFactor`. The wordmark switches to a vertical layout when `dynamicTypeSize.isAccessibilitySize` is true.
  - 5, previews: each of the three onboarding views has Default and Accessibility XXXL (`.accessibility5`) previews.
  - 6, exact copy: `HowItWorksView` displays "NearMe shows you practice copies of everyday apps, so you can learn safely. It never looks at your other apps."
  - 6, explainer flow: heading is "How NearMe works", with one "continue" button. Renamed the view/file and route, added `advanceFromHowItWorks()`, and removed the permission resolver and unused grant flag.
  - 6, other claims: required `git grep` returns no matches; inspection of other screen-related source strings found no remaining screen-watching claim in visible or spoken app copy.
  - 7, quick: always uses the current checkout; hashes `project.yml` contents and the sorted file paths under all three source roots into `build/.xcodegen-hash`. Regenerates only when that hash changes or the generated project is missing. Updates the hash only after successful generation. Reuses a booted iPhone (otherwise selects/boots one), incrementally builds into `build/`, installs, launches and prints elapsed seconds.
  - 7, documentation: usage comment/error, README command table and Mac testing guide all list `quick` and explain its behavior.
  - 7, simulator failures: enables `inherit_errexit` where supported, with explicit failure propagation for older macOS Bash too. All simulator modes reject selection/boot/readiness failures and empty IDs before building or launching. Also rejects an empty physical-device ID.
- Verify commands run and results:
  - `python scripts/tests/test_mac_run.py`: PASS, 6 tests in 29.960 seconds using Git Bash 5.2 and mocked Apple tools. Covers cache reuse; project content changes; source add/edit/rename/remove in all three roots; missing generated project; booted-device reuse and fallback boot; generation/build failures; list/boot/readiness/no-device/empty-ID failures across quick, sim, test and eval; and preserved test/eval build arguments. No real Git operations, Xcode builds or simulator launches occur in these tests.
  - `bash -n scripts/mac-run.sh` using `C:/Program Files/Git/bin/bash.exe`: PASS.
  - `git diff --check`: PASS.
  - `git grep -n -i -E "see your screen|watch(es|ing)? (what|your)|on screen while" -- NearMe/`: no matches, expected exit 1.
  - PowerShell recursive source search (including the new untracked view) for the four removed permission identifiers: no matches.
  - This machine has no Swift or Xcode. `bash scripts/mac-run.sh --current`, Swift compilation, hosted unit tests, previews and actual simulator layout checks were NOT run here. The owner's Mac remains the gate; CI is manual only.
  - `git add` and `git diff --cached --check` succeeded, but `git commit -m "P02b: Make onboarding readable and honest; add quick Mac runs"` failed: `Unable to create '.git/index.lock': Permission denied`. No commit was created. Changes remain uncommitted; the manager must stage this final report update and commit them.
- Mac test steps for the owner:
  1. In the repository on `task/P02b-onboarding-text-copy`, run `python3 scripts/tests/test_mac_run.py`, then `bash scripts/mac-run.sh --current`, then `bash scripts/mac-run.sh test --current`. Confirm generation/build/launch and hosted unit tests succeed.
  2. Run `xcrun simctl list devices available`. Choose the smallest current iPhone simulator available in Xcode (create that device in Xcode's simulator manager if absent). Run `xcrun simctl shutdown all`, then `xcrun simctl boot <chosen-UDID>`, replacing `<chosen-UDID>` with that device's actual identifier. Run `bash scripts/mac-run.sh quick`; confirm it launches on that already booted device without switching branches or pulling.
  3. At the default text size, walk welcome -> greeting -> How NearMe works -> session. Confirm the exact explanation, one continue action, and no screen-access prompt. End the session to return to onboarding.
  4. In simulator Settings > Accessibility > Display & Text Size > Larger Text, enable Larger Accessibility Sizes and move the slider to maximum. Relaunch NearMe if necessary. Walk all three screens, scrolling to every line and button. Confirm the wordmark stacks, text wraps without shrinking/truncation, and nothing is obscured by the status bar, Dynamic Island or home indicator. Repeat with Bold Text enabled.
  5. Open `NearMe.xcodeproj` in Xcode and render both previews in each onboarding file. Confirm the default and `.accessibility5` previews compile and display all content with reachable actions. Spot-check other screens' primary buttons because their shared wrapping behavior changed.
  6. Run `bash scripts/mac-run.sh quick` twice. Confirm the second run skips project generation, reuses the same booted iPhone, installs/launches and prints elapsed seconds; inspect `build/.xcodegen-hash` and `build/xcodebuild.log`. The mock suite checks generation invalidation and failure paths without altering the real project or simulator inventory.
- Not done / risks / questions: Real Swift compilation, simulator safe-area/large-text checks, and native macOS Bash execution remain pending. The shared button now wraps at natural height everywhere, so include the noted spot-check outside onboarding. Existing forced light appearance and fixed color palette are outside this task's scope. No secrets or generated Xcode project were added. Git could not write its lock file in the sandbox; stopped uncommitted as instructed. The post-commit `docs/LOG.md` line was not appended because the commit failed and the user explicitly requested stopping in that case; the manager should append it after committing.
