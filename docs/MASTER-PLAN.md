# Apple AI Hackathon — Family Screen Companion

> **Master product, engineering, judging and demo handoff for another AI coding agent**  
> **Prepared:** 24 October 2026 (Sydney time)  
> **Status:** Concept and MVP planning; no implementation is claimed to exist  
> **Working name:** **NearMe** (placeholder; rename freely)  
> **Primary prize target:** Best Community / Social Good Project  
> **Secondary opportunities:** Best ElevenLabs project; Best SCX project (only if genuine integration works); potential enterprise narrative later.

## 0. Instructions for the receiving agent

You are taking over a hackathon project, not reading a finished technical specification. Treat **verified facts**, **user requirements**, **design recommendations**, and **open technical questions** separately. Validate uncertain platform APIs, permissions, model capability, device requirements, language coverage, sponsor SDK versions, privacy claims and hackathon submission rules **before making promises or designing around them**.

The owner wants a **high-scoring, functional Apple-native demo**, not a generic chatbot or a pitch-only concept. They appreciate tough critique. Work in English even if the owner speaks Hindi/Hinglish. Prioritise one dependable end-to-end flow and judge-facing demonstration over breadth. When changes are proposed, explain what judges will actually see and why the change earns points.

**Definition of success:** A parent or grandparent, unfamiliar with a digital interface, can speak in a comfortable language, ask for help with the **currently visible** screen, receive a short and accurate next-step instruction, and complete a real task with minimal anxiety. When supported by the device, the core guidance should survive disconnection from the internet. A family member's consented cloned voice is an **optional connected-mode emotional layer**, not a blocker for core assistance.

---

## 1. Hackathon context and official requirements

**Official event:** [AI On Apple — Sydney Hackathon (Luma)](https://luma.com/apple-ai-hackathon)  
**Organiser:** The App Blueprint  
**When:** 23–25 October 2026  
**Where:** Level 3, 20 Martin Place, Sydney NSW, Australia  
**Nature:** In-person, build a working AI-native Apple-platform prototype and present it live. This event is independent of Apple Inc.

### Event schedule (as posted)

| Day | Time | Activity |
|---|---|---|
| Friday 23 Oct | 6:00–9:00 pm | Pre-event |
| Saturday 24 Oct | 10:00 am–8:00 pm | Hacking |
| Sunday 25 Oct | 10:00 am–2:00 pm | Hacking |
| Sunday 25 Oct | From 2:00 pm | Judging and closing |

**Allowed/encouraged Apple platforms:** iPhone, iPad, Mac, Apple Watch, Vision Pro. **It is not iPhone-only.** The page welcomes iOS, macOS, visionOS, tvOS and ML developers. Actual platform choice should be decided by hands-on permission/API tests.

**Themes the organiser explicitly welcomes:** private/offline on-device AI; native intelligent assistants; multimodal voice/camera/sensors/spatial experiences; social-impact applications; surprising new ideas.

**Broad organiser judging language:** innovation, technical craft, impact and quality of live demo. The **more specific 1–5 scoring rubric below came from participant photographs**, not the public Luma copy.

### Prize list from Luma (not a promise of eligibility)

- Best Enterprise Solution using AI on Apple: **2 Mac minis**.
- Best Community/Social Good Project using AI on Apple: **2 Mac minis**.
- Best Project built with SCX: **AUD 1,290 SCX credit per team member**.
- Best Project built with ElevenLabs: **USD 897 ElevenLabs plan (3 months) per team member**.
- Winning teams also receive **AUD 425 SCX credit per member** and **USD 297 ElevenLabs plan (3 months) per member**.
- Each attendee: **AUD 100 SCX credit** and **USD 22 ElevenLabs credit**.

**Unconfirmed organisational details to ask organisers:** exact submission format/deadline, team-size cap, demo time limit, whether the four scored criteria all apply to both enterprise and community categories, tie-breaks, eligibility for multiple prizes, and any limitations on pre-event code.

---

## 2. EXACT judging rubric transcribed from user's five photos

**Source:** Photos of the in-person event's "Prizes" → "How You're Judged" screen, supplied directly in this conversation. Below are the photographed scoring descriptions (minor punctuation normalised). These are the most important implementation constraints.

**Each criterion scored from 1 through 5.** A footer in the photos says organisers and guest judges score each criterion 1–5 for a **maximum of 20**; winners announced Sunday at 4:00 pm. It appears that there are **four** five-point categories. **Confirm with organisers** whether enterprise and community are both scored for every submission, or whether each prize uses a category-specific interpretation.

### 2.1 Core ML / Core AI / Apple Intelligence (purple brain)

| Score | Photographed description |
|---|---|
| **1** | Just a chat wrapper around a foundation model — no other function |
| **2** | Basic prompting only; little integration beyond the model itself |
| **3** | Model plus one extra piece (e.g. a simple data pull), but shallow |
| **4** | Model + real integration — e.g. MCP or an API, with sensible data handling |
| **5** | Model + MCP/data retrieval + PII-aware handling, delivering an end-to-end function, not just a feature |

**Meaning for this project:** Need real screen context, sensible processing of potentially sensitive UI data, structured next-step generation, consent controls, and working completion state. MCP is an **example of integration, not necessarily a mandatory technology**, and exposing users' on-screen PII to cloud models would undermine this score.

### 2.2 Execution & Craft (pink brush)

| Score | Photographed description |
|---|---|
| **1** | Barely functional, no attention to UI/UX |
| **2** | Works, but interface is rough or incomplete |
| **3** | Solid build, reasonably clean and usable |
| **4** | Polished, considered interactions, on-brand feel |
| **5** | Exceptional craft — near shippable, delightful to use |

**Meaning:** One stable polished workflow; big readable controls, precise highlights, low-latency response, smooth voice interruptions, understandable permissions, clear progress, trustworthy error recovery, attractive SwiftUI native interface. An Apple-style white-background video can help storytelling, but does not earn craft points without the functional app.

### 2.3 Enterprise Value (green hammer)

| Score | Photographed description |
|---|---|
| **1** | No enterprise relevance; pillars not addressed |
| **2** | Vague angle; one pillar touched superficially |
| **3** | Reasonable value story on at least one pillar |
| **4** | Strong case across two of security / cost / architecture |
| **5** | Compelling, credible pitch across all three pillars |

**Three named enterprise pillars:** security, cost, architecture. User notes additionally mention productivity, performance, bandwidth, capacity and inference spend = demand × cost per unit.

**For this project:** Enterprise story is secondary. A future deployer could be a library, community centre, council, digital inclusion provider, bank or service desk. Avoid asserting partnerships. Show device-vs-cloud data boundary, reduced cloud inference workload for routine tasks, realistic deployment/permissions/costs. Do not make up measured savings.

### 2.4 Community & Social Impact (blue globe)

| Score | Photographed description |
|---|---|
| **1** | No clear social benefit articulated |
| **2** | Vague angle, limited real-world applicability |
| **3** | Reasonable benefit, plausible real-world use |
| **4** | Strong, well-articulated impact with a clear beneficiary group |
| **5** | Compelling, well-executed, meaningful real-world impact |

**For this project:** Precisely identify parents, grandparents, older adults and other digitally excluded people; demonstrate one relevant real task; ideally conduct rapid testing with one or more real intended users (with consent), and be precise about what was actually validated. Family connection is an emotional story, not itself evidence of improved digital independence.

### 2.5 Judge-score strategy and honesty

**Current hypothetical baseline (not actual judge feedback):** Core AI 4/5, Craft 3/5, Enterprise 2/5, Community 4/5 = **13/20**. This estimate was given conversationally before implementation. It is *not* the product's measured score.

**Aspirational target:** Core AI 5, Craft 5, Community 5, Enterprise 3–4 (18–19/20 if all categories count). These are stretch goals, not a guarantee. Core success is a demonstrably working product.

**Non-negotiable:** Do not claim 5/5 technical depth merely by connecting cloud TTS to a chatbot. Demonstrate a real context→planning→guidance→completion loop and privacy controls.

---

## 3. Original notes from presentations (participant notes, not verified industry facts)

These notes were recorded in WhatsApp messages during event presentations:

- Apple design: **Feel, Craft, Simplify, Familiar; Sense of Humanity**.
- Follow Apple's Human Interface Guidelines; use Swift/Xcode skills; consider a widget only if helpful.
- Suggested presentation vibe: Apple-style intention/story video, minimal white background. A reference mentioned was Apple's **2013 “Intention”** video.
- Model choices mentioned: **Core ML** (bring/convert your own device model), **MLX** (Apple-silicon model stack), **Foundation Models framework** (built-in model where compatible).
- Concepts: personal context, world knowledge, app action, on-screen awareness; contextual intelligence is more useful than basic chat.
- Enterprise themes: performance, security, cost, productivity, analysis, agentic functionality; compute, bandwidth, capacity; **spend = demand × cost per unit**.
- A figure in notes says **“76% AI decision makers are concerned about data leaks”**. **UNVERIFIED statistic; do not quote as fact in the final pitch until finding a reputable original source and methodology.**
- SCX sovereign inference and SambaNova hardware were mentioned; confirm actual vendor stack and contract/compliance claims independently before pitching them.

---

## 4. Problem, audience and story

### Problem

Many parents and grandparents are uncomfortable navigating unfamiliar digital interfaces. They call their adult children for help with mundane but confusing steps: locating a setting, sending a photograph, finding a feature inside an application, or finishing an online process. Remote family members cannot reliably provide real-time visual guidance over a phone call. English-only instructions create another barrier for people who are more comfortable with Hindi or Hinglish.

### Audience

- **Primary:** Sighted older adults/parents/grandparents who can operate a phone/computer but struggle with unfamiliar apps and digital navigation. Do not casually promise a certified assistive technology for blind users.
- **Secondary:** New technology users, migrants facing language barriers, first-time computer users.
- **Optional institutional angle:** Community organisations and digital-literacy programmes helping the same users.

### Core positioning

> **“Digital independence, with a familiar voice.”**

One-sentence pitch:

> **NearMe is an Apple-native, voice-first digital companion that understands the screen a person has chosen to share and guides them through everyday technology in their own language—even when connectivity is unavailable on supported devices—with the optional comfort of a loved one's consented voice.**

### Emotional opening, based on owner's own experience

The founder lives in Sydney, physically far from family in India. Parents/grandparents sometimes struggle with apps; the founder cannot always guide them over the phone. With a person's permission, the founder's voice could be cloned using ElevenLabs so the family hears a familiar-sounding guide. This is **an AI in a relative's voice, not the relative speaking live**. Maintain clear disclosures and opt-out.

The product should reduce dependency rather than impersonate a loved one. Warmth must not compromise accuracy or transparency.

---

## 5. Prior art and differentiation — do not pretend this is a new category

### Most important reference: prior prototype (Melbourne winner)

Official prior project: https://devpost.com/software/prior prototype

It won **Most Impactful — Social Good** at Melbourne's Mobile AI Build Weekend. Its own published features include:

- Voice-first goal understanding.
- Opening supported apps by URL scheme / universal links.
- User-activated screen capture with ReplayKit.
- Vision OCR/screen recognition + Apple Foundation Models generating the next plain-language instruction.
- ElevenLabs speech input/output.
- Step-by-step repeated screen guidance.
- Tap-to-Explain and a stuck detector (three unsuccessful taps).

**WARNING:** Screen-by-screen AI guidance, app launching, voice instructions and stuck detection are **already prior prototype features**, not new features invented by this project. A different UI and storytelling alone are not technical differentiation. Do not say “we don't know prior prototype” to judges; acknowledge the category and demonstrate an actual improvement.

prior prototype lists multilingual functionality, widget/Shortcuts, stronger open-ended language understanding, and user testing as future work. These are opportunities to explore but not guaranteed competitive gaps forever.

### Competitive context

Consumer assistants such as Copilot Vision and other computer-use agents may offer screen/vision assistance or automated tasks. **Exact device, market, offline and feature availability must be re-verified from official documentation.** Do not claim that all competitors lack mobile support, or that all competitor processing always occurs outside Australia. Avoid unverified feature-by-feature comparisons to products whose branding and capabilities change rapidly.

### Credible proposed differentiation (must be implemented and demonstrated)

1. **Reliable true offline *core* guidance** on a specific supported device and task, confirmed by an airplane-mode/network-off demo—not merely cached scripts or marketing text.
2. **Multilingual Hindi/English input + plain-language Hindi/Hinglish guidance**, if offline speech recognition and speech output actually work in chosen runtime; otherwise label as connected-only or limit claims.
3. **A family voice layer** using explicitly consented ElevenLabs voice cloning when online; optional locally cached phrases and a clearly labelled non-cloned offline TTS fallback. Voice clone ≠ local/offline model.
4. **Teach-me vs guide-me interaction:** Help the human tap and learn; possibly fade prompts or offer optional hints as confidence increases, without inventing learning outcome evidence.
5. **Private-by-design screen scope:** Process only the current window/page or a screen the user deliberately shares; no covert surveillance, no persistent recordings, no unintended cloud upload of passwords or other secrets.

**Positioning caution:** The founder initially wanted help on **any currently visible app**, not only forms. That's a long-term product goal; a weekend MVP can be honestly scoped to a few tested flows. Never imply arbitrary cross-app capabilities are solved without proving them.

---

## 6. Desired user experience

### Typical flow (the aspirational product)

1. User opens the companion and presses **“Help me”** (large accessible target).
2. Assistant clearly requests permission to inspect the current screen or selected active window. Indicator shows when observation is active.
3. User speaks: “Mujhe WhatsApp pe photo kaise bhejni hai?” or “How do I change this setting?”
4. Local speech recognition transcribes on supported languages/devices, else transparently uses a connected option if consented.
5. Screen understanding extracts visible text/UI element candidates; excludes/redacts obvious secrets where possible.
6. Apple on-device intelligence or another local rule/model proposes **one next step**, grounded in the current screen—never hallucinate a button not present.
7. Assistant reads a short instruction in the user's preferred language, optionally in a family member's cloned voice when online.
8. Assistant may highlight target UI element if supported and safe; user performs the action.
9. Assistant observes a new state **only with ongoing explicit permission**, verifies progress, corrects failures, and concludes once completed.
10. Voice disclosure, privacy controls and a clear stop button remain available.

### Interaction rules

- **Guide rather than secretly take actions.** Any eventual automated action needs clear permission, safe scope and confirmation.
- Speak one step at a time. Use original UI label exactly, even while explaining in Hindi/Hinglish: “Tap **Settings** in the top-right.”
- Never ask users to say passwords or OTPs aloud. Detect/avoid payments, banking, medical portals, authentication screens and other high-risk contexts in MVP.
- If element position/intent is uncertain, ask the user to verify or tap rather than inventing an answer.
- Permit interruption, repeat, slower speech, and a simple “Stop guiding” control.
- Don't retain a screen history by default. Ephemeral memory in RAM still needs a defined lifecycle and handling.

### Accessibility and native craft

Large typography, high contrast, Dynamic Type support, VoiceOver labels, simple onboarding, clear state indicators, understandable mic/screen permission requests, responsive animations, quiet UI, reassuring but not patronising tone. Native SwiftUI for the chosen platform. Widget/App Intent only if it serves the flow, not for checkbox theatre.

---

## 7. Platform decision: DON'T guess; spike immediately

### iPhone-first option

Pros: direct relevance to parents' smartphones, compelling portability/social impact.  
Cons: third-party apps cannot read or manipulate arbitrary other apps via unrestricted iOS accessibility APIs; app launches through deep links work only where supported; user-initiated ReplayKit capture/broadcast must follow permission and operating-system constraints; cross-app overlays, annotations and observation loop may be restricted. **Validate on a real iPhone early.**

### macOS-first option

Pros: desktop Accessibility APIs can expose eligible UI hierarchy with consent; ScreenCaptureKit can capture designated windows/displays with user permission; visible overlay and highlighted elements may be more practical; Mac is explicitly allowed by hackathon.  
Cons: accessibility permissions, secure-field exclusion, app-specific UI tree limitations, screen-capture permissions, OCR fallback latency, WindowServer changes. A Mac demo is less representative of a grandparent's phone if storytelling implies an iPhone-only experience.

### visionOS misconception to avoid

Apple **Vision** (OCR/computer vision framework) and **visionOS** (Vision Pro operating system) are different. Neither automatically grants unrestricted access to the contents of every third-party application's active window. Do not cite “visionOS” as proof that screen awareness is unrestricted.

### Decision gate — first 60–90 minutes

Build tiny throwaway proof-of-concept(s) on the available hardware:

- Can the app lawfully receive and parse the selected foreground interface after clear consent?
- Can it identify two target buttons in a real third-party workflow?
- Can it respond within usable latency and track a changed screen?
- Can that exact flow still work with Wi-Fi/cellular disconnected?
- Does target device support the built-in Apple model and chosen offline speech language?

**Pick one main platform based on evidence.** Avoid doing Mac+iPhone+Vision Pro all at once. Secondary platform is stretch.

---

## 8. Proposed architecture: hybrid with an offline-first core

```text
User voice ──> Speech recognition adapter (local when supported)
                        │
                        ▼
Selected screen/window ─> Permissioned screen observation
                        ├─> Accessibility element tree (macOS where supported)
                        └─> OCR / Vision over explicitly captured frame
                        │
                        ▼
             Screen-state normaliser
             [visible text, controls, labels, rectangles, confidence]
                        │
                        ▼
             Privacy & risk filter
             [passwords/OTP/PII redaction, sensitive screens block]
                        │
                        ▼
             Guidance engine
             ├─ Local Foundation Models / local logic [OFFLINE]
             └─ Optional SCX hosted text inference [ONLINE, CONSENTED]
                        │
                        ▼
             Structured StepInstruction + validator
             [grounding, target, expected action, safety, confidence]
                        │
                        ▼
             Guidance UI + optional highlight
                        │
                        ▼
             Speech output adapter
             ├─ Local OS TTS / prerecorded clips [OFFLINE]
             └─ ElevenLabs cloned voice [ONLINE]
                        │
                        ▼
             User acts → observe next state → completion/repair
```

### Model / component selection

- **SwiftUI:** native presentation, permissions UI, transitions and accessibility.
- **Apple Foundation Models:** built-in **on-device text model** for compatible devices and supported versions. Verify availability at runtime; do not promise all iPhones support it. Do not assume it directly accepts screenshot images; use Vision/OCR/UI-tree text and structured input.
- **Vision:** OCR and eligible computer-vision processing of authorised image frames.
- **macOS Accessibility API:** hierarchical UI metadata where consented and available; no guarantee for every app.
- **ReplayKit (iOS):** explore user-initiated screen broadcasts/capture; check what frames an app/extension actually gets and lifecycle boundaries before architecture commitments.
- **ScreenCaptureKit (macOS):** screen/window frame acquisition, requiring appropriate permission.
- **Core ML:** optional specialised local element detection if OCR/UI hierarchy insufficient. Training/conversion is *not* necessary to win unless it solves a real bottleneck.
- **MLX:** optional for models on Apple silicon Mac; not intrinsically necessary to ship an iPhone app.
- **ElevenLabs:** connected speech synthesis, consented personal voice option; online dependencies should be isolated behind an interface.
- **SCX.ai / SCXSwiftKit:** optional **Australian-hosted cloud text inference**; **not** offline and not automatically a legal government-compliance certification.

**CRITICAL CURRENT SDK LIMITATION:** [SCXSwiftKit's public README](https://github.com/SouthernCrossAI/SCXSwiftKit) says its Foundation Models integration needs **Xcode 27** and lists **“Image input (vision): No.”** Its hosted text integration can consume **safely extracted/sanitised text**, not raw screenshot vision through that package. Validate latest dependency and target OS before adopting it. SCX may offer other interfaces; those require independent checking.

### Suggested protocol boundaries (implementation sketch)

- `ScreenObservationProvider`: get authorised current-screen state.
- `SpeechInputProvider`: transcribe supported speech.
- `PrivacyFilter`: classify, mask and block sensitive content.
- `GuidanceModel`: produce a structured next-step suggestion.
- `StepValidator`: confirm proposed target exists in current observed state and meets confidence threshold.
- `SpeechOutputProvider`: local TTS, ElevenLabs online, cached clips.
- `ConnectivityManager`: detect online/offline and choose capability transparently.
- `SessionCoordinator`: orchestrate start/stop, task progress, screen changes and error recovery.

Suggested model output object:

```json
{
  "spoken_instruction": "Tap Settings in the top-right corner.",
  "target_label": "Settings",
  "target_element_id": "settings-button",
  "target_rect": null,
  "user_action": "tap",
  "expected_next_state": "settings_screen",
  "confidence": 0.93,
  "needs_clarification": false,
  "safety_blocked": false
}
```

**The confidence number must be properly calibrated or labelled heuristic; never equate an LLM's self-assigned 0.93 with measured accuracy.** Actual element IDs come from the current observed UI, not fabricated by the model.

### The offline promise (define narrowly and test!)

Offline means the full chosen demo path functions with network disabled:

1. Local user input (voice *if supported offline*, otherwise offline typed request as explicit fallback).
2. Local authorised screen observation.
3. Local OCR/UI interpretation.
4. Local next-step reasoning/validation.
5. Local spoken output **in languages the platform actually supports offline**.

**No internet means:** no SCX requests, no live ElevenLabs cloud voice synthesis, no real-time external app data. A target application may itself fail offline even if the companion works. Therefore select an **offline-capable target workflow** for the airplane-mode demonstration (e.g. navigating local device settings or an offline mock app), and disclose scope honestly.

**Family-voice limitation:** Creating/downloading a cloned ElevenLabs voice does **not** imply a locally runnable synthesiser. An ElevenLabs-generated voice identifier is not a self-contained offline voice model. Cached audio handles only known phrases. Fully dynamic cloned speech offline requires a distinct supported local voice-synthesis system and a legal/consented voice pipeline—not part of the MVP unless validated.

### Hindi and Hinglish capability matrix (must empirically fill)

| Stage | Target | Offline status at start |
|---|---|---|
| Speech-to-text | English | Verify on chosen device/OS |
| Speech-to-text | Hindi | **Unverified; must test** |
| Intent + reasoning | Hindi/Hinglish | **Unverified for Apple's local model; test** |
| Text-to-speech | English | Verify local system voice |
| Text-to-speech | Hindi | **Verify local voice installed and pronunciation** |
| Cloned family voice | Hindi/English | **ElevenLabs online; verify clone quality** |
| Cloned family voice | Offline dynamic | **Not promised; assume unavailable** |

Don't overclaim multilingual end-to-end offline functionality merely because ElevenLabs supports Hindi online.

---

## 9. Privacy, security, data residency and consent

**Privacy is central, but precision matters:**

- **On-device** = processed locally on the user's Apple hardware.
- **Australia-hosted** = data leaves the device, but is processed/stored in an Australian region *if provider configuration and contractual terms truly ensure this*.
- **No prompt retention** = an account/product setting or contractual promise; verify applicable logs, crash reporting, sub-processors and metadata.
- **Government compliant** = a specific auditable claim, not proven solely by being Australian or listed in a procurement directory.

### Minimum privacy controls for MVP

1. Clear, revocable permission for screen observation and microphone.
2. Visible indicator while listening/observing.
3. Manual stop control at all times.
4. Ephemeral frames processed in memory; no screenshots, transcription or screen recording persisted by default.
5. Avoid secrets/password fields and sensitive screens; redact sensitive text from any hosted prompt.
6. No raw screenshot to SCXSwiftKit text endpoint; no cloud transmission without disclosure/consent.
7. If optional connected model active, show **“Online processing”** and what limited data is sent.
8. Separate consent to clone, store, share, revoke and use an individual's voice. Never clone third parties without authorisation.
9. Voice always disclosed as AI-generated; don't imply the loved one is on a live call.
10. Minimise analytics, and do not hardcode keys in a distributable client. Clarify deletion/retention if storing profiles or voice asset IDs.

### Optional SCX strategy

Use the **local-first path** for routine screen navigation. For difficult language reasoning, optionally send a **sanitised text-only representation** to SCX in a verified Australian region with explicit consent. Benchmark quality, cost and latency against pure local inference. This can strengthen an enterprise/security narrative **only with actual measurement and proof of data flow**.

---

## 10. Build priority and scope: what to ship this weekend

### P0 — indispensable MVP

- [ ] Pick platform and one proven task after permission/API spike.
- [ ] SwiftUI app with welcoming, senior-friendly UX and clear permission flow.
- [ ] User starts/stops voice-guided session deliberately.
- [ ] Obtain authorised current-screen information in a way legal for platform.
- [ ] Generate one grounded next-step instruction from **actual** screen elements/OCR.
- [ ] Display and speak instruction with a reliable local voice.
- [ ] Detect task progression / new screen and generate subsequent step.
- [ ] Complete at least **one** workflow genuinely end-to-end.
- [ ] Offline working run on supported hardware, with an honest fallback if speech/language isn't locally available.
- [ ] Error/retry handling, visible privacy state, no recording saved by default.

### P1 — high-value competitive improvements

- [ ] Hindi guidance + Hindi speech path if technically proven.
- [ ] Natural English/Hinglish mixed language handling with UI labels preserved.
- [ ] Consent-based ElevenLabs cloned voice connected path.
- [ ] Highlight target UI rectangle if platform permits.
- [ ] “Repeat,” “slower,” “why this step,” and “I'm stuck” controls.
- [ ] Gentle adaptive support: Full guidance / Hints only.
- [ ] Simple live privacy architecture view for judges, not user-facing clutter.
- [ ] One real target-user feedback session; log only consented observations.

### P2 — only if P0 stable

- [ ] Australian hosted SCX text inference fallback with demonstrable data residency/settings.
- [ ] Optional downloadable set of common family-voice clips.
- [ ] Local session progress and learning measurement (opt-in only).
- [ ] App Intent/Shortcuts or widget where helpful.
- [ ] Second platform or second third-party app workflow.
- [ ] Institution deployment model/cost calculation.

### Explicit NON-goals for the hackathon

- Full autonomous control of arbitrary apps.
- Guaranteed works-across-everything screen access on iOS.
- Continuous covert observation of user screens.
- A permanent history of private screens.
- Unvalidated clinical accessibility claims.
- Offline dynamic ElevenLabs cloned-voice inference without confirmed engine.
- Banking/payments/OTP assistance or legal/medical advice.
- Training a new foundation model from scratch.

---

## 11. Concrete task/demo options

**Option A (safest offline demo):** Navigate a local, offline-capable app's settings/preferences and change a benign value. Assistant observes the actual current screen, points to real options, explains in simple language, confirms completion. If demonstration uses a custom mock application, **say so**—it proves the pipeline but **does not demonstrate cross-app integration**.

**Option B (more compelling, higher permission risk):** Help a user use a real third-party application (e.g. locating a feature in a utility or settings screen) with the user performing every tap. Validate cross-app capture and highlights first; never fake a transition.

**Option C (emotionally strongest connected demo):** Parent asks in Hindi how to send a photo; assistant explains screen-specific steps using a consented family voice. If WhatsApp or another third-party app is required, internet and platform restrictions may limit the offline segment. **Split demo into online family voice and separate offline guidance demonstration**, and communicate honestly that not all third-party app operations work offline.

**Recommended:** P0 is A or B depending on feasibility. C is a short addition once the core works. Choose a task understandable to a judge in 10 seconds and completable in under two minutes.

---

## 12. Proposed demonstration and narrative (2–3 minutes; confirm actual limit)

**0:00–0:20 — Human story.** “I study/work in Sydney. My parents and grandparents are far away and call me when technology gets confusing. I cannot always be beside them. We built a companion that lets them get unstuck themselves.” Use only the founder's true personal story.

**0:20–0:35 — Problem + one-line solution.** “They should not need to speak tech jargon or hand over their whole screen to a stranger.” Show calm native UI, big Help Me button, clear observation permission.

**0:35–1:20 — Real working demo.** Speak a goal in English or Hindi (if tested). Observe the **currently visible app** with consent. Narrate one concise grounded instruction, optionally highlight a real target, let a human tap, observe next screen, confirm task success.

**1:20–1:45 — Offline proof.** Disable network. Do a **new dynamic instruction** in an offline-capable interface to prove reasoning, not only replaying an audio file. Show that cloud requests stop, and state precisely what still works.

**1:45–2:05 — Emotional differentiator.** Turn connectivity back on if needed and play generated voice guidance in a consented family voice. Clearly label it “AI using a family member's voice.” If this isn't stable, show local voice as primary and pre-generated authorised clip as a limited feature, not a fake live synthesis demo.

**2:05–2:30 — Architecture and impact.** One clean diagram: UI observation → local understanding → safety → guidance → speech. Show local-only privacy boundary, optional Australian text cloud path if included, and one real-user feedback result if obtained. End: “Technology should make your family more independent, not more dependent.”

**Video aesthetic (optional):** minimal Apple-style visuals, clean typography/white or warm neutral background, human hands using a device, no exaggerated emotional manipulation. Prioritise real, in-app live proof over video polish.

### Demo contingency

- Rehearse on the **exact physical device** and OS build, connected and disconnected.
- If network goes down, local speech / UI instructions must remain usable where tested.
- Have a prerecorded demo video labelled as prerecorded; no deceptive live claims.
- No sensitive user data, credentials or personal family conversations on stage.
- Have exact permission dialogs primed so judges see consent without wasting time.

---

## 13. Work plan with stage gates (Sat 24 / Sun 25 Oct)

**Saturday morning (first 1–2 hours): validation and platform selection.**

1. Confirm available Mac/iPhone hardware, OS and Xcode versions.
2. Run screen-observation proof: active screen → identified element → changed screen.
3. Test on-device Foundation Models availability and latency (or fallback local deterministic approach).
4. Test English/Hindi input and local output in airplane mode.
5. Decide **one platform and one complete demo workflow**. Freeze scope.

**Saturday mid-day: build core loop.**

6. SwiftUI onboarding and consent controls.
7. Screen observation + OCR/element extraction + structured screen state.
8. Guidance model prompt/tool/data schema and validation.
9. Local voice readout and screen-change state machine.
10. Complete first real task end-to-end; capture latency/failure notes.

**Saturday afternoon/evening: reliability and differentiator.**

11. Fix failures on two changed screens; ensure guidance never targets unknown elements.
12. Offline test with network disabled.
13. Add Hindi/Hinglish where proven.
14. Add ElevenLabs clone with explicit consent + online disclosure if time.
15. User-test with one representative person if feasible; avoid claiming population-wide effectiveness.

**Sunday 10:00–12:00: polish.**

16. Large text, contrast, confidence/error states, progress confirmations.
17. Make demo performant; cache **non-sensitive UI assets**, not private screenshots.
18. Optional SCX integration only if fully functional and safe.
19. Final script and score-by-score evidence checklist.

**Sunday 12:00–2:00: hardening and rehearsals.**

20. Full live run on physical device, then one run with airplane mode.
21. Backup recorded screen demo and offline mode explanation.
22. Freeze features, remove unstable integrations, rehearse transitions and exact timing.
23. Submit in organiser-required format by confirmed deadline.

**Hard gate:** No new headline feature after Sunday noon unless it fixes a blocker. A reliable 4/5 craft score beats a failed 5/5 aspiration.

---

## 14. Tests and acceptance criteria

### Functional acceptance

- [ ] Real authorised screen state drives guidance; swapping a visible label changes the next instruction.
- [ ] Every suggested tap is traceable to an observed UI element or explicitly marked uncertain.
- [ ] The assistant does not secretly operate a target app.
- [ ] App can stop observations immediately, and user can confirm that session ended.
- [ ] The selected offline path works after network shutdown; no hidden server call succeeds or hangs.
- [ ] Remote ElevenLabs service failure causes graceful local voice fallback.
- [ ] Screens with a password/OTP or obviously private fields are masked or assistance is appropriately blocked.
- [ ] Accuracy and latency tested over repeated runs on the actual demonstration path.
- [ ] English language flow complete; Hindi flow shown only if all required parts work.

### Suggested instrumentation (no invented measurements)

Record **observed**: start-to-first-instruction latency, time per guidance step, number of correct grounded targets over N attempts, network requests in offline mode, number of instructions needed to complete a task, and number of user-recovery prompts. Report actual test count and hardware/OS.

### Fast sanity-test matrix

| Scenario | Expected |
|---|---|
| Correct target visible | Specific accurate next instruction |
| UI changed | Updated guidance, no stale instruction |
| Requested button absent | Ask for clarification; no hallucinated target |
| Offline | Local path still works on validated hardware |
| ElevenLabs unavailable | Local TTS fallback |
| Password/payment screen | Mask/suspend sensitive guidance |
| User says stop | Microphone/screen capture stop promptly |
| Hindi command | Correct transcription/interpretation only if tested |

---

## 15. Scorecard: map real product evidence to photographed rubric

| Criterion | MVP proof to show judge | Target | Risk |
|---|---|---:|---|
| Core AI | Real screen extraction + grounded model instruction + safety filter + repeated end-to-end loop | 5 | Model invents unavailable control; no actual cross-app access |
| Execution & Craft | Elegant native UI, stable voice interaction, clear consent, responsive highlights, recoverable failures | 5 | Permission interruptions / latency / demo crash |
| Enterprise Value | Credible security/cost/architecture discussion, local-cloud boundary; optional anonymised admin support use case | 3–4 | Project primarily social; no actual enterprise deployment or measured cost savings |
| Community & Social Impact | Clear elderly/family beneficiary, multilingual access, genuine usable task, rapid user feedback | 5 | Emotion without evidence; patronising design; Hindi/offline claims untested |

**Potential 18–19/20 is aspirational only.** Exact all-four scoring applicability should be clarified with judges. If judges weight social and enterprise separately, pivot narration accordingly rather than distorting core product.

---

## 16. Open questions the coding agent should resolve first

1. Which physical device(s), OS versions, Xcode version and team members are available right now?
2. Which iOS/macOS APIs can *actually* observe the currently visible target app with an accepted permission flow?
3. Can a nonprivileged iOS app receive third-party app frames while guidance UI remains visible? How does ReplayKit extension lifecycle affect voice output/highlights?
4. Is a **Mac-first** implementation materially more reliable? If yes, use it openly, since Mac is allowed.
5. Does Apple's device-local model run on the demo device? What are token/context/latency limitations?
6. Can the chosen speech recognition genuinely function offline for **Hindi** and English?
7. Can Hindi TTS run locally with an installed voice? Is Hinglish intelligible without awkward code switching?
8. Which precise ElevenLabs clone plan/API is accessible under sponsor credit, and what are the voice-owner consent requirements?
9. Can SCXSwiftKit be built with installed Xcode? Is its Australian regional processing configured and supported by documented contract/settings? Does it need to be in MVP at all?
10. How will the app correctly ground and highlight a target UI element, especially when OCR coordinates drift?
11. What exact user workflow still works while the target application itself is offline?
12. What authentic user feedback can be gathered in the remaining time without making unsupported impact claims?
13. Does the organiser want both enterprise and social categories scored for each team?

---

## 17. Risks and kill criteria

| Risk | Severity | Mitigation / pivot |
|---|---|---|
| Arbitrary screen capture not viable on iOS | Critical | Switch to proven Mac Accessibility/ScreenCaptureKit path, or restrict to explicit in-app/shared content. Don't fake cross-app operation. |
| Hindi offline voice pipeline unavailable | High | Honest English offline baseline; Hindi connected mode if available; text fallback. |
| On-device local reasoning unreliable/unsupported | Critical | Scope workflow to OCR-grounded deterministic helper and only supported hardware; do not claim arbitrary reasoning. |
| ElevenLabs network dependence | Medium | Local OS TTS first; cloud cloned voice is optional connected feature. |
| Same idea as prior prototype | High | Differentiation must be proved through multilingual/local continuity, safe family voice, or superior verified workflow—not just cosmetics. |
| SCX privacy/compliance overstated | High | Label AU-hosted cloud processing precisely; avoid legal compliance claims without evidence. |
| Screen reads secrets or gives dangerous direction | High | Redaction, blocked categories, explicit consent, user-controlled action. |
| Overbuilding multiple platforms | High | Freeze on single validated platform and flow. |
| Demo relies on venue Wi-Fi | High | Offline-first run + properly disclosed backup recording. |

**Kill rule:** If no legitimate end-to-end screen-awareness loop can be demonstrated on the available hardware by Saturday mid-day, reduce scope to a clearly disclosed in-app guided simulation or pivot idea immediately. Do not spend the entire weekend on unverified OS privileges.

---

## 18. Source links and evidence provenance

### Verified public links

- Sydney official event: https://luma.com/apple-ai-hackathon
- prior prototype official prior-art submission: https://devpost.com/software/prior prototype
- Melbourne gallery: https://mobile-ai-build-weekend.devpost.com/project-gallery
- SCX Swift SDK/readme: https://github.com/SouthernCrossAI/SCXSwiftKit
- SCX: https://scx.ai/
- ElevenLabs: https://elevenlabs.io/
- Apple developer docs: https://developer.apple.com/documentation/
- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/

### User-provided primary evidence

The owner supplied:

- **Five photos** of the event's 1–5 judging criteria. Detailed transcription is in section 2.
- **Two WhatsApp screenshot note pages** from event talks. Interpretation is in section 3.
- A long discussion defining this product, the family's cross-border context, explicit desire for current-screen help (not arbitrary off-screen app surveillance), Hindi/Hinglish support, hybrid offline behavior, SCX privacy and ElevenLabs family voice. See sections 4–9.

### Claims expressly NOT confirmed

- 76% data-leak statistic and its source.
- SCX blanket Australian government certification or universal Australian-only data residency.
- All other assistants' offline/mobile capabilities.
- Hindi offline speech recognition and local-model quality on the chosen device.
- Dynamic offline ElevenLabs cloned voice.
- Unrestricted iPhone cross-app awareness or programmatic tapping.
- Winning score, winning likelihood, or impact without real users.

---

## 19. Prompt the next agent can follow immediately

> You are the lead AI + Apple engineer for **NearMe**, a Sydney Apple AI Hackathon social-impact prototype. Read this full plan, especially the photographed rubric in section 2. Our job is to build an Apple-native, permissioned, screen-aware voice guide for parents/grandparents unfamiliar with technology. It should provide a grounded next step based on the screen currently shared, not operate unseen apps or pretend to be a live relative. The aspiration is an honestly offline-capable core, English/Hindi guidance when technically available, and optional consented ElevenLabs family voice online. **Do not treat SCX cloud calls as offline**. First identify the available devices, Xcode/OS, API permissions, and choose the narrowest genuine end-to-end task. Spike feasibility immediately; propose architecture only after checking actual APIs. Prioritise Core AI, Execution & Craft, Community Impact; enterprise security/cost/architecture is secondary but must be argued accurately. Build something live, tested and polished. Report uncertainties and blockers, refuse to fake demos, and regularly map progress against 1–5 judging criteria.

**Final motto:** *Not another assistant that takes over. A companion that helps your family confidently do it themselves.*
