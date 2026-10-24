# NearMe HIG notes

Use for older, non-technical people on macOS and iOS. Apply these rules to existing UI; log behavior-dependent gaps as N11b exceptions. Values marked **NearMe** are product targets, not universal Apple requirements. Sources checked 24 October 2026.

## Rules

1. **Keep one step visible.** Use native controls, plain verbs and one short instruction containing the real control's exact label. Match spoken and visible guidance; retain typed input and visible Repeat, Slower, I'm stuck and Stop. Avoid technical explanations in the task flow. [Overview][overview], [Accessibility][accessibility]
2. **Use readable system type.** Use `.largeTitle` for the welcome heading, `.title` for the current instruction and `.body` for explanations/control labels; never below body for instructions. iOS default Large sizes are 34/28/17 pt respectively. **NearMe:** Mac instruction at least 22 pt, supporting text 17 pt. Support iOS Dynamic Type through Accessibility XXXL and Bold Text; native macOS has no Dynamic Type, so target an app text scale through 200%. Never shrink text to fit. [Typography][typography]
3. **Make targets forgiving.** **NearMe minimum:** 44 x 44 pt hit regions on both platforms, with about 12 pt separation for bordered controls. Apple's accessibility table lists default/minimum sizes of 44/28 pt on iOS and 28/20 pt on Mac; use our larger floor for older users. Keep visible pressed, focused and disabled states. [Buttons][buttons], [Accessibility][accessibility]
4. **Use adaptive system colors only.** Use primary/label text, system backgrounds (`windowBackgroundColor` on Mac; `systemBackground` on iOS), system separators and system accent colors. No fixed RGB/hex palette or forced appearance. Follow system light/dark changes immediately; don't use color alone for meaning. [Color][color], [Dark Mode][dark]
5. **Measure legibility.** **NearMe:** aim for 7:1 instruction-text contrast; require at least 4.5:1 for all informative text and target 3:1 for meaningful icons/boundaries. Check actual rendered backgrounds in both appearances. Increase Contrast strengthens boundaries and ring strokes; Reduce Transparency uses an opaque system background. Keep instruction content off clear glass; prefer standard materials and native control treatments. [Dark Mode][dark], [Materials][materials]
6. **Pair symbols with words.** Give every app-owned control an SF Symbol and visible label: Help me `hand.raised`, Speak `mic`, Repeat `arrow.counterclockwise`, Slower `tortoise`, I'm stuck `questionmark.circle`, Stop `stop.fill`, Settings `gearshape`, Continue `arrow.right`, text size `textformat.size`. Match symbol weight/scale to type; use semantic colors. Preserve standard OS window controls. [SF Symbols][symbols], [Buttons][buttons]
7. **Reflow, don't truncate.** Put the instruction first, group related actions, stack controls at large sizes, and allow vertical scrolling with Stop reachable. Respect safe areas and the keyboard on iOS; keep primary actions within comfortable thumb reach. Preserve iOS's existing walkthrough; don't imply it can inspect or overlay other apps. [Layout][layout], [Designing for iOS][ios]
8. **Keep the Mac helper unobtrusive.** Use a movable, compact native window titled “NearMe”, with accessible controls and keyboard focus indicators. Keep instruction/Stop away from a clipped bottom bar. Preserve the nonactivating, click-through ring without covering its target label. **Deliberate exception:** guidance stays visible across apps, unlike ordinary panels that hide when inactive. [Panels][panels], [Windows][windows], [Designing for macOS][macos]
9. **Make motion optional.** No flashing, continuous ring pulsing or bouncing controls. With Reduce Motion, remove travel/scale animations and animated listening effects; use static state symbols and immediate updates or a brief fade. Never delay Stop for animation. [Motion][motion]
10. **Expose meaning to VoiceOver.** Label controls by action (“Repeat instruction”, “Stop guidance”); provide relevant values and hints without repeating “button”. Order focus: instruction, state, actions. Hide decorative symbols/ring from accessibility; expose their meaning in the instruction. Announce meaningful state changes once without stealing focus or overlapping guidance speech. Support keyboard operation. [Accessibility][accessibility]
11. **Teach only the next action.** Keep onboarding short; offer a safe example and optional, revisitable help. Defer family-voice setup. Explain permissions at the point of need; retain typed entry when voice is declined. [Onboarding][onboarding]
12. **Explain access honestly before prompting.** Mac Accessibility: “NearMe reads control names and positions in the app you're using so it can point out your next step. You do the clicking.” Explain that it is enabled in System Settings > Privacy & Security > Accessibility. Microphone: “NearMe uses the microphone when you choose Speak to understand your request.” Present only truthful platform-specific copy; disclose online speech/voice processing when enabled. A dedicated pre-alert has one “Continue” button opening the system prompt, never “Allow” or a fake alert; denial remains the system's choice. Explain denied access and recovery without repeated prompts. [Privacy / requesting permission][privacy]
13. **Show truthful states.** Pair text and symbol: Listening (`mic.fill`) only during capture; Watching your screen (`eye`) only during Mac observation; Offline (`wifi.slash`) as a separate connectivity badge, not an activity state. Label online voice separately. Show Ready/Stopped and plain-language errors; label the iOS simulated walkthrough as such instead of claiming live observation. [Feedback][feedback], [Privacy][privacy]
14. **Keep speech controllable.** Speak one step, keep its text available, and expose Repeat/Slower/Stop. Respect system volume and audio routing; pause on headphone removal. Avoid competing with VoiceOver. Silence nonessential sounds in silent mode; play requested speech only in an explicit guidance context. [Playing audio][audio]
15. **Use restrained feedback.** Pair completion/error text with an optional brief sound and standard iOS success/error haptic where supported. Never rely on hearing or vibration, require haptics on Mac, or buzz on every screen change. Respect sound/haptic preferences; no background music. [Feedback][feedback], [Playing audio][audio]

[overview]: https://developer.apple.com/design/human-interface-guidelines/
[accessibility]: https://developer.apple.com/design/human-interface-guidelines/accessibility
[typography]: https://developer.apple.com/design/human-interface-guidelines/typography
[color]: https://developer.apple.com/design/human-interface-guidelines/color
[dark]: https://developer.apple.com/design/human-interface-guidelines/dark-mode
[materials]: https://developer.apple.com/design/human-interface-guidelines/materials
[symbols]: https://developer.apple.com/design/human-interface-guidelines/sf-symbols
[layout]: https://developer.apple.com/design/human-interface-guidelines/layout
[motion]: https://developer.apple.com/design/human-interface-guidelines/motion
[privacy]: https://developer.apple.com/design/human-interface-guidelines/privacy#Requesting-permission
[onboarding]: https://developer.apple.com/design/human-interface-guidelines/onboarding
[feedback]: https://developer.apple.com/design/human-interface-guidelines/feedback
[panels]: https://developer.apple.com/design/human-interface-guidelines/panels
[windows]: https://developer.apple.com/design/human-interface-guidelines/windows
[buttons]: https://developer.apple.com/design/human-interface-guidelines/buttons
[audio]: https://developer.apple.com/design/human-interface-guidelines/playing-audio
[macos]: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
[ios]: https://developer.apple.com/design/human-interface-guidelines/designing-for-ios

## UI review checklist

1. [ ] One instruction; exact label; visible and spoken copies agree. (Rule 1)
2. [ ] Text hierarchy, minimums and largest sizes pass without shrinking. (2)
3. [ ] All app control hit regions meet 44 x 44 pt. (3)
4. [ ] System colors adapt to light/dark mode. (4)
5. [ ] Contrast measured; Increase Contrast/Reduce Transparency pass. (5)
6. [ ] Every app control has a meaningful SF Symbol and label. (6)
7. [ ] Layout reflows; safe areas, keyboard and Stop remain usable. (7)
8. [ ] Mac panel moves; ring stays click-through; panel exception documented. (8)
9. [ ] Reduce Motion removes nonessential animation. (9)
10. [ ] VoiceOver labels/order and keyboard access verified. (10)
11. [ ] Brief onboarding; optional help and typed fallback retained. (11)
12. [ ] Permission explanations, prompts and denial recovery are truthful. (12)
13. [ ] Listening/watching/offline and iOS simulation states are accurate. (13)
14. [ ] Repeat/Slower/Stop, audio routing and VoiceOver coexistence checked. (14)
15. [ ] Sound/haptics are optional, restrained and visually duplicated. (15)
