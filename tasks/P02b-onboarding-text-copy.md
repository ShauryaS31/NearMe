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
