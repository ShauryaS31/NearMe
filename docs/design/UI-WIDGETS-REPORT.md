# NearMe: UI Upgrade Plan and Widget Feasibility Report

**Research date:** 24 October 2026  
**Audience:** NearMe designer, developer and project owner  
**Platform:** SwiftUI, minimum iOS 26.5, Xcode 27.1  
**Purpose:** A practical Apple-source-based design plan and hackathon implementation brief.

## Part 1: HIG research and UI upgrade plan

**Recommendation: make NearMe feel polished through readable typography, consistent spacing, native controls and clear voice states. Use Liquid Glass mainly for navigation and controls, while keeping instructions and captions on solid backgrounds.** This follows Apple’s separation between the content layer and the floating control layer. [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

Research checked on **24 October 2026**. Apple confirms Xcode 27.1 and documents the iOS 27 design refinements discussed below. All dimensions, designs, priorities and effort estimates labelled **proposed** are recommendations, not Apple requirements or validated research findings about NearMe’s users. [Xcode 27.1 release](https://developer.apple.com/news/releases/?id=10152026a)

The existing SwiftUI components and project configuration were also inspected. The research machine has no Swift or Xcode, so nothing here has been compiled or tested on an iPhone. Repository links below are relative to this file; Apple source links work independently of the repository.

### 1. What the current Apple design language means for NearMe

| Area | Confirmed Apple guidance or capability | Proposed NearMe treatment |
|---|---|---|
| **Materials** | Liquid Glass belongs primarily to navigation and controls. Apple advises against using it throughout the content layer. [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) | Solid caption and instruction surfaces. Let native navigation supply most of the glass. |
| **iOS 27** | SwiftUI gains refined Liquid Glass that responds to a system tint slider, along with additional resizing and toolbar behaviour. [WWDC26: What’s new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/) | Adopt the system appearance. Avoid recreating its tint or optical effects yourself. |
| **Colour** | Use dynamic colours, apply tint selectively and reserve strong colour emphasis for important actions. Glass can change appearance with the content behind it. [Colour](https://developer.apple.com/design/human-interface-guidelines/color) | One system-blue action colour. Primary text stays `.primary`; backgrounds use semantic system colours. |
| **Typography** | Dynamic Type supports user-selected text sizes; Apple recommends supporting substantial enlargement. [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | System text styles throughout. Large, left-aligned instructions; avoid tiny uppercase status labels. |
| **Symbols** | SF Symbols convey familiar concepts and integrate with interface text and controls. [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) | Pair symbols with visible words: “Repeat”, “Settings”, “Talk to NearMe”. |
| **Navigation and tab bars** | Standard SwiftUI structures receive the system design, including floating toolbar and tab-bar treatments. [WWDC25: Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/) | One `NavigationStack` rooted at Home. Keep Settings accessible. A tab bar adds little value to the current flow. |
| **Sheets** | Sheets suit brief, contextual tasks. Medium and large detents support different amounts of content. [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) | Use a large sheet for “I’m stuck” and voice selection. Provide a visible dismissal control. |
| **Buttons** | System styles supply interaction states and accessibility behaviour. Prominence should express action hierarchy. [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) | One prominent action per screen, with clearly bordered secondary actions. |
| **Motion** | Native Liquid Glass adapts to Reduce Motion, Reduce Transparency and Increase Contrast. [WWDC25: Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/) | Keep custom animation restrained. No continuously moving background or decorative breathing orb. |

**Useful APIs**

- Start with `NavigationStack`, `.toolbar`, `Form`, `List`, `.sheet`, `Button`, `Toggle` and `Picker`. Standard components already participate in Apple’s design system. [WWDC25 SwiftUI design](https://developer.apple.com/videos/play/wwdc2025/323/)
- For custom floating controls, use `.glassEffect()`, `.buttonStyle(.glass)` or `.buttonStyle(.glassProminent)`. Group multiple custom glass elements in `GlassEffectContainer`; do not add another glass layer around an already styled button. [Applying Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- iOS 27 adds toolbar visibility priorities, pinned placement and minimisation options. Keep essential NearMe actions visible, and availability-check any iOS 27-only API because the minimum remains iOS 26.5. [WWDC26 SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/)

A proposed primary button can remain simple:

```swift
Button(action: startTalking) {
    Label("Talk to NearMe", systemImage: "mic.fill")
        .font(.title2.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
}
.buttonStyle(.borderedProminent)
.tint(Color(uiColor: .systemBlue))
```

Here, **64 pt is a proposed minimum**, not a fixed height or Apple requirement. The solid prominent style is intentional for this important content-area action. [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)

### 2. Accessibility requirements

#### Text, targets and contrast

- **Support Dynamic Type through `.accessibility5`.** Allow text wrapping, vertical scrolling and taller controls. At accessibility sizes, stack controls vertically. Do not shrink text to squeeze a screen into its original layout. Apple explicitly recommends testing the largest sizes. [Larger Text evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria)
- **Apple’s general minimum target is 44 × 44 pt.** Proposed NearMe targets are at least **56 pt high**, with **64–80 pt** for the main Talk action and **12 pt** between adjacent actions. Those larger values require user testing. [Apple UI design tips](https://developer.apple.com/design/tips/)
- **Proposed contrast target: at least 4.5:1 for all essential reading text**, including coach instructions. This is deliberately stricter than relying on the lower large-text allowance. Measure light and dark appearances, plus Increase Contrast. Semantic colours help but do not remove the need to check combinations. [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

#### System settings and assistive technology

| Setting | Proposed implementation and test |
|---|---|
| **Reduce Motion** | Read `accessibilityReduceMotion` for custom effects. Replace pulses and animated transitions with stable state labels. Native glass handles its own adaptation. [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/) |
| **Reduce Transparency** | Keep reading surfaces solid by default. Check native glass with the setting enabled; remove custom translucent layers that still obscure text. [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/) |
| **VoiceOver** | Use real buttons and labels, meaningful state values and logical reading order. Announce meaningful transitions, not every partial transcript update. Test the complete task without looking at the screen. [SwiftUI accessibility fundamentals](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals) |
| **Bold Text** | Use system fonts and flexible layouts. Check that heavier text neither clips nor hides controls. [Testing accessibility settings](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app) |
| **Button Shapes** | Prefer standard controls. Any custom control must remain visibly identifiable as interactive. Current documentation provides `accessibilityShowBorders`; the older `accessibilityShowButtonShapes` property is deprecated. [Show Borders](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityshowborders) |
| **Differentiate Without Colour** | State changes need words and symbols: “Listening” plus microphone, “Speaking” plus speaker. Colour alone must not communicate readiness or failure. [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) |

**Where glass can hurt:** busy content behind controls, similarly coloured foregrounds and backgrounds, and too many overlapping transparent surfaces create legibility problems. For NearMe, keep the transcript and current step opaque, and avoid the clear glass variant for essential reading. [Colour](https://developer.apple.com/design/human-interface-guidelines/color), [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)

Do not assume every person over 65 needs the same settings. Offer a clear default and respect their system preferences. Apple frames accessible interfaces as adaptable to individual needs. [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

### 3. Voice and conversational UI

Apple provides useful precedents: Siri can be interrupted, Siri accessibility settings accommodate different interaction needs, and Live Captions exposes readable transcription with pause and expansion controls. These are interaction references, not a public, reusable Siri conversation-screen component. [Siri interaction](https://support.apple.com/en-euro/guide/iphone/iph83aad8922/ios), [Siri accessibility](https://support.apple.com/en-gb/guide/iphone/iphaff1d606/26/ios/26), [Live Captions](https://support.apple.com/en-gb/guide/iphone/iphe0990f7bb/27/ios/27)

**Proposed NearMe state model:**

| State | Visible content | Main action |
|---|---|---|
| Ready | `mic.fill`, “What would you like help with?” | **Talk to NearMe** |
| Preparing microphone | “Getting ready to listen” | **Cancel** |
| Listening | `mic.fill`, “Listening”, live transcript | **Finish speaking** |
| Preparing answer | `ProgressView`, “Preparing your next step” | **Cancel** |
| Speaking | `speaker.wave.2.fill`, complete current response | **Stop speaking** |
| Paused or interrupted | “We paused here”, current instruction preserved | **Continue** |

These are proposed labels and behaviours based on Apple’s guidance to make processing status understandable and give people control. Do not show a fabricated percentage while generating an answer. [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback), [Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators)

**Transcript treatment**

- Put **“You said”** above recognised speech and **“NearMe”** above the response.
- Make the current response the strongest text element. Place earlier turns behind “Earlier conversation”.
- Keep captions available during speech. Stop automatic scrolling when someone scrolls back.
- Offer “Say it again” and “Type instead”.
- For the deadline, use explicit tap-to-interrupt. Natural spoken interruption requires audio coordination and device testing; it is not a visual-only change.

These are NearMe proposals informed by Apple’s transcription controls and guidance to let people refine AI interactions. [Live Captions](https://support.apple.com/en-gb/guide/iphone/iphe0990f7bb/27/ios/27), [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)

### 4. Step-by-step guidance and recovery

**Proposed coach structure**

1. Task title: “Send a photo”.
2. Progress: “Step 3 of 6”, only when the total is known.
3. One instruction using the guide’s verified wording.
4. Contextual **Open app** action, when supported.
5. Prominent **Done** button.
6. Secondary **Repeat** and **I’m stuck** buttons.
7. Visible **Stop guidance** action.

Use a single action label, rather than “Done / Next”. Advance only when the user confirms completion. Treat the progress indicator as completed steps, not elapsed time. Apple recommends clear button purposes and accurate progress reporting. [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators)

**Proposed recovery copy**

| Situation | Message and action |
|---|---|
| “I’m stuck” | “That’s okay. What can you see?” Offer **Repeat more slowly**, **Go back one step**, **Describe my screen** where already supported. |
| Speech not understood | “I didn’t catch that.” Offer **Try again** and **Type instead**. |
| Online voice unavailable | “The online voice isn’t available. Use the iPhone voice?” |
| Speech assets unavailable | Explain that speech needs setup or a download. Keep typed guidance available. |
| No active guide | “What would you like help with?” plus two example requests. |
| Guide paused | Preserve the current step and offer **Resume**. |
| Cannot open another app | Explain how to open it manually, then how to return to NearMe. |

These are proposed recovery patterns based on actionable feedback and helping people revise unsuccessful requests. [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback), [Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)

Do not promise that every feature works offline merely because it uses on-device models. Speech assets and model availability still matter. The speech router already handles asset installation and an on-device fallback. [WWDC25: SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/), [local speech router](../../NearMe/Services/Speech/VoiceInputRouter.swift)

### 5. Onboarding and permissions

**Proposed flow: explain briefly, then let the person try.**

- Combine welcome and greeting into one screen where practical.
- Explain: **“Tell NearMe what you want to do. We’ll guide you one step at a time. You stay in control.”**
- Offer a short practice example.
- Postpone voice selection and other optional setup.
- Make the explainer available later in Settings.

Apple recommends short onboarding and postponing nonessential configuration. [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

**Request microphone access when the person chooses Talk.** Explain the immediate purpose, then present the system request. If using a separate permission explanation screen, use a neutral continuation action rather than imitating the system permission alert. [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy/)

**Important speech-permission distinction:** Apple’s documented speech-authorisation process applies to `SFSpeechRecognizer`; its `SpeechAnalyzer` transcriber modules do not send speech to Apple’s servers. Match permission requests to the actual selected implementation, while still requesting microphone access. [Speech permissions](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition), [Microphone usage description](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSMicrophoneUsageDescription)

The current [PermissionsManager.swift](../../NearMe/Services/Permissions/PermissionsManager.swift) requests both permissions and requires both to succeed. Review that alongside the SpeechAnalyzer-first router.

If permission is denied, offer **Type instead** and **Open Settings**. Do not repeatedly send the person through an explanation that cannot produce another system prompt. This is proposed recovery behaviour.

### 6. Concrete screen redesigns

#### Shared design specification

The following are **proposed NearMe tokens**, grounded in Apple’s semantic colour, adaptable layout and system-control guidance. [Colour](https://developer.apple.com/design/human-interface-guidelines/color), [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)

| Token | Proposed value |
|---|---|
| Screen background | `Color(uiColor: .systemBackground)` |
| Grouped screens | `.systemGroupedBackground` |
| Grouped cards | `.secondarySystemGroupedBackground` |
| Main text | `.primary` |
| Supporting text | `.secondary`, subject to contrast testing |
| Action tint | `Color(uiColor: .systemBlue)` |
| Destructive action | System destructive role |
| Screen horizontal inset | 20 pt |
| Section spacing | 24 pt |
| Related elements | 12 pt |
| Card padding | 20 pt |
| Card radius | 20 pt, only where a custom card is needed |
| Main instructions | `.title2`, semibold |
| Captions and explanations | `.body`; use `.title3` where it improves the reading hierarchy |
| Buttons | `.headline`; main Talk button `.title2` |
| Minimum action height | 56 pt; allow growth |

Use the default system font design consistently. The existing theme already contains Dynamic Type styles and spacing tokens, so this can be an incremental change. [Theme.swift](../../NearMe/Views/Components/Theme.swift)

#### Screen-by-screen brief

All layouts and symbol choices below are proposed. Confirm symbol availability in the installed SF Symbols catalogue during implementation.

| Screen | Concrete proposed redesign | SwiftUI building blocks and Apple basis |
|---|---|---|
| **Welcome** | Small app mark or `hand.wave`; `.largeTitle` “A little help, one step at a time”; two lines of `.body`; full-width **Get started**. Use 24 pt vertical groups and the shared palette. | `ScrollView`, `VStack`, prominent `Button`. [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) |
| **Greeting** | Merge into Welcome if it adds no unique function. If retained: “Hello” plus one useful invitation; no required name entry. `text.bubble`, 24 pt spacing. | `Text`, optional `TextField`, standard button. [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) |
| **Explainer** | Three labelled rows: `mic.fill` **Tell us**; `list.number` **Follow one step**; `hand.raised` **You stay in control**. Rows spaced 20 pt. **Try it now** plus **Skip**. | `Label`, `VStack`; label and description can stack. [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) |
| **Home** | Native “NearMe” title; labelled Settings access using `gearshape`. `.title2` “What would you like help with?” Full-width Talk button, minimum 80 pt. One example underneath. Bordered **Type instead** and a “Practise a train trip” row with `tram.fill`. | `NavigationStack`, `.toolbar`, `ScrollView`, `Button`, `NavigationLink`. [WWDC25 SwiftUI design](https://developer.apple.com/videos/play/wwdc2025/323/) |
| **Conversation** | Short state row; current caption on a solid surface; “You said” beneath or above according to conversation order. Keep 24 pt between groups. Bottom Talk/Stop action plus Type instead. Reduce decorative orb to a small state symbol. | `ScrollViewReader`, `Text`, `ProgressView`, `.safeAreaInset`; move controls into scrolling content if large text leaves insufficient space. [Live Captions](https://support.apple.com/en-gb/guide/iphone/iphe0990f7bb/27/ios/27) |
| **Coach** | Task title, step count, one `.title2` instruction in a 20 pt padded surface. Full-width **Done** using `checkmark`. **Repeat** with `arrow.counterclockwise`; **I’m stuck** with `questionmark.circle`. Open-app action beside its explanatory text. | `ProgressView`, `ScrollView`, standard buttons; vertical actions at accessibility sizes. [Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators) |
| **Trip practice** | Persistent “Practice” label and “No booking will be made”. One question at a time, such as destination. Readable station choices, then a plain journey summary. Use `tram.fill`, `mappin.circle`; 20 pt padding and 12 pt row spacing. Preserve existing simulation behaviour. | `Form`, `Section`, `TextField`, selection rows, `NavigationStack`. [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data) |
| **Settings** | Native grouped form. Sections: Voice, Accessibility help, Privacy, About. Voice choice opens a picker with **Preview voice** using `speaker.wave.2.fill`. Online voice toggle has explanatory text. | `Form`, `Section`, `Picker`, `Toggle`, `NavigationLink`. [SwiftUI accessibility fundamentals](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals) |
| **Privacy** | `lock.shield`; plain-language groups: **What stays on this iPhone**, **What uses the internet**, **What we save**. Describe the online voice service’s actual data use. Body-sized text with 24 pt between groups. | `Form` or `ScrollView`, `Section`, `Text`, policy `Link`. [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy/) |

For “I’m stuck”, use a large contextual sheet with an obvious close action. Avoid a sequence of stacked sheets. [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)

### 7. Top 10: visual impact divided by effort

**Estimates**, assuming existing behaviour works. Impact uses a subjective 1–5 scale. The time estimates are not Apple claims.

| Rank | Change | Impact | Hours | Impact/hour |
|---|---|---:|---:|---:|
| 1 | Replace inconsistent colours with semantic surfaces and one accent. [Colour](https://developer.apple.com/design/human-interface-guidelines/color) | 5 | 0.75 | 6.7 |
| 2 | Replace custom button painting with consistent native styles. [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) | 5 | 0.75 | 6.7 |
| 3 | Unify text styles and remove tiny uppercase statuses. [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | 4 | 0.75 | 5.3 |
| 4 | Apply consistent margins, alignment and spacing. [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) | 4 | 1 | 4.0 |
| 5 | Give voice states clear labels and stable positioning. [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback) | 3 | 0.75 | 4.0 |
| 6 | Standardise navigation and contextual sheets. [SwiftUI design](https://developer.apple.com/videos/play/wwdc2025/323/) | 4 | 1.25 | 3.2 |
| 7 | Rebuild coach hierarchy around one instruction and Done. [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) | 5 | 1.75 | 2.9 |
| 8 | Simplify Home around Talk, one example and practice. [Design principles](https://developer.apple.com/design/human-interface-guidelines/design-principles) | 4 | 1.5 | 2.7 |
| 9 | Apply native form styling to Settings and trip practice. [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) | 3 | 1.5 | 2.0 |
| 10 | Shorten onboarding and improve permission explanations. [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) | 2 | 1 | 2.0 |

**UI-only budget: 11 hours implementation, 3 hours accessibility/device checks, 1 hour contingency.** New speech interruption behaviour, substantial permission-engine changes and widgets are additional scope.

## Part 2: Can NearMe have a widget?

**Yes. Build an “Ask NearMe” launcher first. A Live Activity is the appropriate surface for showing the current step while someone uses another app.** Widgets support deep links into an app; Live Activities support ongoing tasks in the Dynamic Island and on the Lock Screen. [Widget deep links](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity), [Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)

### 1. Home Screen and Lock Screen widgets

#### Sizes and useful designs

| Surface | Supported families to consider | Proposed NearMe content |
|---|---|---|
| Home Screen | `.systemSmall`, `.systemMedium`, `.systemLarge` | Small: **Ask NearMe**. Medium: last saved step plus **Resume**. |
| Lock Screen | `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline` | Circular microphone launcher; rectangular “Resume your guide”. |

These are WidgetKit families, not fixed dimensions across every device. Build and preview each supported family separately. [Supporting widget sizes](https://developer.apple.com/documentation/widgetkit/supporting-additional-widget-sizes)

**Interactive widgets can run App Intents through buttons and toggles**, for example to mark a step complete. A simple app launcher should use `widgetURL` or `Link`. [Widget interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)

#### “Ask NearMe” implementation

Proposed route:

**Tap widget → unlock if needed → open NearMe’s voice screen → check permission and readiness → begin listening with a visible state.**

The deep-link portion is supported by WidgetKit. Automatic listening after arrival is NearMe behaviour that must be implemented and tested. Do not label the widget “Listening” while it is merely displaying a launcher. [Widget deep links](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity)

```swift
VStack(alignment: .leading, spacing: 12) {
    Image(systemName: "mic.fill")
        .font(.largeTitle)
    Text("Ask NearMe")
        .font(.headline)
}
.widgetURL(URL(string: "nearme://ask"))
.containerBackground(.background, for: .widget)
```

Register and validate the URL route in the app. Handle both cold launch and an already-running session. The app receives widget URLs through mechanisms including `.onOpenURL`. [Widget deep links](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity)

#### Audio limitation: an important correction

A widget view is not a continuously running mini-app, so it is unsuitable for hosting a live microphone meter, streaming transcript and voice conversation. WidgetKit archives and renders views through the system. [WWDC26: WidgetKit foundations](https://developer.apple.com/videos/play/wwdc2026/277/)

However, **“a widget can never trigger recording” is too broad**:

- Apple provides `AudioRecordingIntent` for recording actions.
- Its documentation requires an active Live Activity throughout recording on iOS, iPadOS and watchOS.
- Audio playback actions also have a specialised `AudioPlaybackIntent`.

That does not make the widget view itself an audio engine. For this deadline, open the app before recording. A complete, reliable background conversational implementation for NearMe has not been confirmed from Apple’s documentation. [AudioRecordingIntent](https://developer.apple.com/documentation/AppIntents/AudioRecordingIntent), [Widget interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)

#### Refresh limits and the current-step widget

Apple describes a typical budget of **40–70 timeline reloads per day for frequently viewed widgets**, with variable scheduling. This is not a guaranteed refresh interval or a universal hard cap. Foreground-app reloads and widget-intent interactions are among the exceptions. [Keeping widgets up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)

For NearMe:

- Save a concise snapshot after each confirmed step.
- Request `WidgetCenter.shared.reloadTimelines(ofKind:)`.
- Show **“Last saved step”** or an update time where appropriate.
- Treat the widget as a resume surface, not guaranteed live progress.

These are proposed safeguards against stale information, based on WidgetKit’s scheduling model. [Keeping widgets up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)

**Estimated effort:** launcher **3–4 hours**; Lock Screen variant **0.5–1 hour extra**; current-step widget **3–5 hours extra**, including shared data and stale-state handling.

### 2. Live Activities and Dynamic Island

#### Can the step remain visible inside WhatsApp or Settings?

**Yes, on supported devices through the Dynamic Island.** The expanded presentation can show more content and interactive controls. It is not a freely positioned overlay over another app, and the compact presentation cannot accommodate a complete instruction plus several large buttons. iOS 27 also supports Dynamic Island Live Activities in landscape. [WWDC26: Live Activities essentials](https://developer.apple.com/videos/play/wwdc2026/223/)

**Proposed presentations**

- **Compact:** NearMe symbol and “3/6”.
- **Minimal:** concise progress symbol.
- **Expanded:** short instruction, **Done**, **Open NearMe**.
- **Lock Screen:** task title, current instruction, **Done**, **Resume**.
- **No usable Dynamic Island:** retain the Lock Screen and return-to-app paths.

Apple requires designs for the compact, minimal, expanded and Lock Screen presentations. [Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)

#### What Done can do

A button backed by `LiveActivityIntent` can update NearMe’s own progress and publish the next state. It does not confirm what happened inside WhatsApp or perform the task there. For NearMe, **Done means the user says they completed the step**. [Interactive Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)

Proposed implementation safeguards:

- Persist the session and step before updating the presentation.
- Include session identity and expected step revision in the action.
- Reject duplicate or outdated Done actions.
- Use prewritten guide steps for the first version.
- If advancing requires fresh model work or clarification, open NearMe.

These are engineering recommendations, not ActivityKit requirements.

#### Rules and limits

- Active for up to **8 hours**; potentially retained on the Lock Screen for **4 additional hours**.
- Combined static and dynamic activity data must stay within **4 KB**.
- The Live Activity itself cannot fetch network data or location.
- Update from the app using ActivityKit, or from a server using ActivityKit push notifications. [ActivityKit constraints](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- High-priority push updates have a system-controlled budget and can be throttled. Apple does not provide a universal guaranteed updates-per-second allowance in this guidance. [ActivityKit push updates](https://developer.apple.com/documentation/ActivityKit/starting-and-updating-live-activities-with-activitykit-push-notifications)

A Live Activity is not a general grant of continuous background execution. For a local coach, update when the user acts or the app is running; do not build a polling loop around it. [Live Activities essentials](https://developer.apple.com/videos/play/wwdc2026/223/)

**Setup:** widget extension, `ActivityAttributes`, `ContentState`, `ActivityConfiguration`, `DynamicIsland`, `NSSupportsLiveActivities`, and lifecycle handling. Check authorisation before starting. Shared storage is useful for progress actions; the activity’s display data is supplied through ActivityKit. [ActivityKit implementation](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

**Estimated effort:** read-only version **5–7 hours**; dependable Done/Next version **8–12 hours total**, potentially more if progress persistence needs restructuring.

**Verdict:** strong second-phase feature. Its usability for this audience needs testing because expanding the Dynamic Island introduces another interaction.

### 3. Control Center, Lock Screen controls and Action Button

WidgetKit controls can expose app actions in Control Center, on the Lock Screen and through the Action Button. Use `ControlWidget`, `StaticControlConfiguration` and `ControlWidgetButton`. An `OpenIntent` can open the relevant app destination, with intent code included in both app and extension targets. [Creating controls](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system)

**Proposed control:** microphone symbol, **Talk to NearMe**.

- Open the voice screen using the same routing and readiness checks as the widget.
- Do not present it as an always-listening toggle.
- The person must configure the control or Action Button; the app should provide optional setup guidance.
- Hardware availability and authentication affect the Action Button experience. App Shortcuts offer another route to Action Button configuration. [App Intents](https://developer.apple.com/documentation/appintents), [WWDC25: Get to know App Intents](https://developer.apple.com/videos/play/wwdc2025/244/)

**Estimated effort:** **1.5–3 hours extra** once routing and an intent exist. A plain launcher needs no shared progress database.

### 4. Siri and Shortcuts

**Recommended second integration:** an App Shortcut that opens NearMe ready to listen.

Define an intent and an `AppShortcutsProvider`. Suggested phrases include:

```swift
AppShortcut(
    intent: TalkToNearMeIntent(),
    phrases: [
        "Ask \(.applicationName)",
        "Talk to \(.applicationName)"
    ],
    shortTitle: "Ask NearMe",
    systemImageName: "mic.fill"
)
```

Apple requires the application-name placeholder in App Shortcut trigger phrases. App Shortcuts become available through system experiences without requiring the person to construct a shortcut manually. [WWDC25: Get to know App Intents](https://developer.apple.com/videos/play/wwdc2025/244/)

**Scope the promise carefully:** “Hey Siri, ask NearMe” can invoke a shortcut, but this does not automatically give NearMe a complete Siri-hosted conversation. Free-form request capture and richer Siri integration are additional work. Test phrase recognition, unlock behaviour and the transition from Siri audio to NearMe audio on a device. [App Intents overview](https://developer.apple.com/documentation/appintents)

WWDC26 adds execution targeting and longer-running intent capabilities. They are useful future options, but unnecessary for a basic foreground launcher. [WWDC26 App Intents](https://developer.apple.com/videos/play/wwdc2026/345/)

**Estimated effort:** **1–2 hours extra** after the app’s listening-entry route works. No widget extension is required for the App Shortcut itself.

### 5. StandBy and Apple Watch

- **StandBy:** reuse the small widget and check its appearance in the charging landscape context. Live Activities also appear there. **Estimate: 0.5–1 hour of additional validation.** [Widget strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy), [Live Activities essentials](https://developer.apple.com/videos/play/wwdc2026/223/)
- **Apple Watch:** an iPhone Live Activity can appear in the Smart Stack without building the whole NearMe experience for watchOS. A dedicated watch app, complication or Watch microphone experience is separate scope. **Estimate: 1–2 hours for mirrored-activity polish; a standalone voice app needs its own estimate.** [Live Activities essentials](https://developer.apple.com/videos/play/wwdc2026/223/)

### 6. Project setup and privacy

The current [project.yml](../../project.yml) declares the app and hosted tests, with no widget extension. The existing [coach progress store](../../NearMe/Models/CoachSession.swift) persists a guide identifier and step index in ordinary app defaults.

**Proposed project work:**

- Add one widget extension target to `project.yml`, embedded in the app.
- Keep Swift 5 mode and existing isolation settings.
- Add shared model and intent files only to targets that need them.
- Use an App Group for a current-step snapshot shared between app and widget.
- A static launcher does not need shared progress data.
- Register deep links and route them through one coordinator.
- Keep generated `NearMe.xcodeproj` out of commits.

Apple documents widget extensions, App Groups and deep links as the relevant integration mechanisms. [Widget strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy), [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups), [Deep links](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity)

**Privacy and review considerations**

- Obtain recording consent and clearly indicate recording. Do not use background audio merely to keep the app alive. [App Review 2.5.14 and 2.5.4](https://developer.apple.com/app-store/review/guidelines/)
- Keep exposed step text generic. Prefer “Choose a recipient” over a person’s name on the Lock Screen; redact sensitive content. [Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- Explain the online voice service accurately. If personal text is sent to a third-party AI service, disclose that sharing and obtain explicit permission. “Natural voice (online)” alone may not explain the data transfer sufficiently. [App Review 5.1.2](https://developer.apple.com/app-store/review/guidelines/)
- Keep widget and shortcut functionality directly related to NearMe, with accurate action names. [App Review 2.5.11 and 2.5.16](https://developer.apple.com/app-store/review/guidelines/)

#### What remains unconfirmed

- Apple does not certify that this particular UI will be easiest for NearMe’s users. Validate it with representative older adults.
- Not every proposed SF Symbol has been verified against the installed SDK.
- A production-ready background recording-and-conversation flow for NearMe has not been confirmed.
- Apple sources do not guarantee WhatsApp URL behaviour or its current button labels. Use verified guide content and test the installed app.
- No Apple source guarantees App Review acceptance or the effort estimates above.

### 7. What to build first

**First: small “Ask NearMe” Home Screen widget.** It directly exposes the core action, uses a documented deep-link mechanism and avoids live-state synchronisation.

**Second: “Ask NearMe” App Shortcut.** It reuses the same app entry point and adds voice-based access through Siri. These priorities are an assessment of usefulness and implementation risk. [Widget deep links](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity), [App Shortcuts](https://developer.apple.com/videos/play/wwdc2025/244/)

Budget **4–6 hours combined**, including device checks, assuming the existing voice engine works reliably.

If **15 hours covers everything**, allocate approximately **8 hours to the highest-priority UI changes, 4 hours to launcher and shortcut, and 3 hours to testing and fixes**. Defer the current-step widget, Live Activity and Control Center control.

---

## One-page developer brief

**Objective:** make NearMe calm, readable and recognisably native, while preserving its existing voice and guidance behaviour.

### Design direction

- Use a single `NavigationStack`, native controls and semantic system colours.
- Keep captions and instructions on solid backgrounds.
- Let system navigation provide most Liquid Glass.
- Use one system-blue primary action per screen. [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)

### Proposed visual specification

- 20 pt screen insets; 24 pt section gaps; 12 pt action gaps.
- `.title2` instructions, `.body` captions, `.headline` buttons.
- Minimum 56 pt action height; 80 pt Home Talk button.
- Allow wrapping, scrolling and vertical action layouts through `.accessibility5`.
- Test light/dark mode, contrast, Bold Text, Button Shapes, Reduce Motion, Reduce Transparency and VoiceOver. [Larger Text criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria), [Accessibility testing](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app)

### Screen priorities

1. Home: Talk, one example, Type instead, Practice, Settings.
2. Coach: task title, accurate step count, one instruction, Done, Repeat, I’m stuck.
3. Conversation: explicit Ready, Listening, Preparing and Speaking states; readable captions and Stop.
4. Settings: native grouped form with truthful online-voice explanation.
5. Onboarding: shorten and request permissions at the relevant action. [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback), [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

### Build first

- Small **Ask NearMe** widget using `widgetURL`.
- **Ask NearMe** App Shortcut using a shared listening-entry route.
- Open the app, check readiness and permission, then visibly begin listening.
- Defer interactive step widgets and Live Activities. [Widget linking](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity), [App Shortcuts](https://developer.apple.com/videos/play/wwdc2025/244/)

### 15-hour combined allocation, estimated

| Work | Hours |
|---|---:|
| Shared styling, Home, Coach, voice-state polish | 8 |
| Widget launcher and App Shortcut | 4 |
| Device testing and fixes | 3 |

### Mac acceptance steps

1. On the owner’s Mac, run `xcodegen generate`, then open `NearMe.xcodeproj`.
2. In Xcode 27.1, select the NearMe scheme and run **Product → Test**.
3. Test on iOS 26.5 and iOS 27.x: largest text, dark mode and each accessibility setting above.
4. Complete one guide using VoiceOver; verify Done advances once, Repeat preserves progress and Stop ends speech.
5. On a physical iPhone, test widget and Siri entry with the app closed, open, locked and with microphone permission denied.
6. Test without the debugger, including offline operation and unavailable online voice. Widget refresh limits differ under debugging. [TimelineProvider testing guidance](https://developer.apple.com/documentation/widgetkit/timelineprovider)

**Release criterion:** the person can identify the next action, read the complete instruction, interrupt speech and recover from a problem without losing their place. This is the proposed NearMe usability target, to validate with users.
