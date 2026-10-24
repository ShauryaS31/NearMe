# P07a: Guide library content (15 guides, content only)

| Field | Value |
|---|---|
| Status | done (owner verify-step check pending) |
| Window | Sat 24 Oct, in parallel with P03a |
| Depends on | - |
| Assignee | codex (git worktree, parallel to P03a) |
| Branch | task/P07a-guides |

## Goal
Write the guide library that P07's coach will read: 15 carefully written, one-action-per-step guides for older users, plus the schema doc. Content only: no Swift, no project.yml changes (P07 wires the files into the app).

## Read
AGENTS.md (no person or prior-project names; metric units; no em dashes); tasks/P07-guided-coach.md items 1 and 3 (how the coach uses guides: it quotes `ui_label_hint` exactly, and its validator only accepts quoted labels that appear as a `ui_label_hint` in the same guide).

## Acceptance criteria
### Files
- [ ] `NearMe/Resources/guides/<id>.json`, one per guide, UTF-8, 2-space indent. ids (snake_case, exactly these): `whatsapp_send_photo`, `whatsapp_video_call`, `whatsapp_voice_message`, `iphone_text_bigger`, `connect_wifi`, `take_screenshot`, `share_photo_from_photos`, `facetime_contact`, `add_contact`, `turn_on_do_not_disturb`, `check_ios_update`, `set_alarm`, `call_from_recents`, `turn_on_torch`, `send_text_message`
- [ ] `docs/design/GUIDES.md`: the schema below, field meanings, writing rules, and how to add a guide
- [ ] `scripts/validate-guides.py` (Python 3, standard library only): checks every file against the schema and rules below, prints one line per problem, exits non-zero on any problem. Run it and include its output in the Dev Report

### Schema (every guide)
```json
{
  "id": "whatsapp_send_photo",
  "title": "Send a photo on WhatsApp",
  "app": "WhatsApp",
  "app_url_scheme": "whatsapp://",
  "aliases": ["send a picture on whatsapp", "photo bhejna whatsapp", "..."],
  "steps": [
    { "instruction": "Open the chat with the person you want to send it to.", "ui_label_hint": "Chats" },
    { "instruction": "Tap the \"+\" button next to the message box.", "ui_label_hint": "+", "verify": true }
  ],
  "source_note": "WhatsApp for iPhone, October 2026 layout (iOS 26/27).",
  "last_checked": "2026-10-24"
}
```
- `app_url_scheme`: optional, only a publicly documented scheme: `whatsapp://` for WhatsApp guides, `sms:` for text message, `tel:` only if a guide dials a number. Omit for Settings, Photos, Clock, Contacts, Phone, FaceTime and Control Centre guides (no private or undocumented URLs such as `App-prefs:`)
- `aliases`: 6 to 10 per guide, lowercase, the ways older people actually ask: plain English ("how do i make the writing bigger"), short forms ("bigger text"), and at least 2 Hinglish or simple mixed phrasings (for example "photo bhejna whatsapp", "whatsapp pe video call kaise kare", "text bada karna hai", "torch on karo")
- `steps`: 3 to 8 per guide. Each `instruction` is ONE action, plain words, at most 2 short sentences, no jargon ("tap", not "select"; "the green button", not "CTA"). Any on-screen label in the instruction is in double quotes and spelled exactly as on screen. `ui_label_hint` is the exact on-screen label (or icon name in plain words, for example "+", "camera icon", "microphone icon") the user looks for in that step; every quoted label in the instruction must equal that step's `ui_label_hint` or another step's `ui_label_hint` in the same guide
- `verify: true` on any step you are not fully sure matches iOS 26/27 or current WhatsApp on iPhone (label wording, position, or order). Be honest: when in doubt, flag it. The owner checks flagged steps on the phone
- `source_note`: which app and version layout the steps describe, and any known variation (for example "Face ID iPhones: side button + volume up; Home button iPhones: side button + Home")
- `last_checked`: "2026-10-24"

### Content rules
- [ ] Accurate for iOS 26/27 and current WhatsApp for iPhone. Prefer the most common path (for example Settings path for text size: "Settings", "Display & Brightness" or "Accessibility", "Display & Text Size", "Larger Text"; pick one path and note the other in `source_note`). Control Centre steps describe swiping down from the top-right corner on Face ID iPhones
- [ ] No invented features, prices, or account details. Never ask the user to type a password or code into NearMe. If a step needs a password (for example Wi-Fi), say "Type the Wi-Fi password, then tap \"Join\"." and nothing more
- [ ] No person names, no brand names other than the apps themselves (WhatsApp, FaceTime, Apple apps), no em dashes, metric units if any
- [ ] Validator passes with 0 problems; Dev Report lists every `verify: true` step as "guide id, step number, what to check"

## Verify
```
python scripts/validate-guides.py
```

<!-- Dev Reports and Reviews appended below. -->

## Dev Report (round 1)

- Date: 2026-10-24 17:03 AEDT
- Changed files: the 15 named `NearMe/Resources/guides/<id>.json` files; `docs/design/GUIDES.md`; `scripts/validate-guides.py`; this task file; the completion entry in `docs/LOG.md`.
- What I did: wrote 15 guides with eight aliases each, including two Hinglish phrasings, and 3 to 8 steps each. Added source URLs, prerequisites, layout variations and honest documentation-only review notes. Wrote the schema, authoring rules, source map and addition workflow. Added a Python 3 standard-library validator with file inventory, schema, formatting, label, language and content checks. Kept all Swift, project configuration and protected documentation unchanged.
- Acceptance criteria:
  - Guide files: all 15 exact ids and filenames exist; UTF-8 without BOM, two-space JSON, final newline. Each guide has the required fields and the specified review date.
  - Schema documentation: `docs/design/GUIDES.md` describes every field, both optional fields, allowed schemes, the complete id/app map, the coach's quote contract, writing rules, validation limits and how to add a guide in a future authorised task.
  - Validator: checks all files; reports one line per detected problem and returns 1 on failure. Checks duplicate ids/keys, unknown fields, JSON types, filenames, counts, lowercase/distinct aliases, mixed-language heuristic, exact quoted-label membership, length limits, formatting, schemes, credential wording and common prohibited content. Semantic accuracy, natural language and exhaustive name/brand detection remain human checks, explicitly documented.
  - Schemes: only `whatsapp://` for the three WhatsApp guides and `sms:` for Messages. All other files omit the field. There is no guide that dials a supplied number, so no `tel:` value or private URL is used.
  - Aliases: 120 total, eight per guide; six English requests and two Hinglish/mixed phrasings in each. Each guide includes a short English request.
  - Steps and labels: 3 to 8 steps per guide; every quoted instruction label matches a hint within the same guide. Instructions stay within two sentences and 200 characters. Separate alarm wheels get separate steps; screenshot press/release is a single brief gesture to avoid holding buttons between coach prompts. The brief's exact Wi-Fi password sentence is the sole compound-action exception.
  - Layout accuracy: reviewed official Apple and available WhatsApp documentation. Uses Display & Brightness > Text Size, top-right Control Centre gestures, the newer FaceTime New Call label, the Phone Unified Calls path with Classic Recents noted, and the full-screen screenshot save path. The current iPhone WhatsApp voice/video articles could not be retrieved; their uncertain actions are flagged. This is not a claim that any guide was verified on an iOS 26/27 phone.
  - Content rules: no example person names, account details, prices, unrelated brands or em dashes. No measurement units were needed. Password entry occurs in Settings using exactly the prescribed sentence. Source notes identify variations and prerequisites; unknown layout details are marked for device review.
  - Verification: validator reports 0 problems. All 36 `verify: true` steps are listed individually below.
- Verify commands run and results:
  - `python scripts/validate-guides.py`: exit 0. Exact output: `Validated 15 guides: 0 problems.`
  - Inline Python regression harness, executed with a PowerShell here-string piped to `python -`: exit 0. Exact output: `Validator regression checks: 56 passed; all 15 guides accepted; no test files written.` Checked malformed UTF-8/JSON, BOM, duplicate keys/ids, non-JSON constants, wrong types, unknown/missing fields, count limits, filenames, mixed-language checks, quoted labels, instruction limits, forbidden schemes/credentials/content, formatting, missing/extra files and valid optional fields/cross-step labels/CRLF. Used in-memory file doubles, with no additional test files.
  - Inline Python failure-path check: exit 0. Exact output: `CLI failure-path check: status 1, one problem line, no traceback.` The status 1 is the validator's expected response to a missing library.
  - Inline Python content-file check: exit 0. Exact output: `Content file checks: 17 files; UTF-8, no BOM/em dash/trailing whitespace, final newline.` This covers the 15 JSON files, schema document and validator, including then-untracked files.
  - `git diff --check`: exit 0, no output. `git status --short --untracked-files=all`: only task-authorised content paths before this report was appended.
  - `git add --` with the 18 explicit content/report paths: returned exit 0. Git warned that its configured checkout policy may convert LF to CRLF; the validator accepts both line endings.
  - Final `python scripts/validate-guides.py` and `git diff --cached --check`: exit 0. An inline report check confirmed all 36 flagged guide/step pairs are listed. The staged diff contained only the 18 authorised content/report files.
  - `git commit -m "P07a: Add guide library content, schema and validator"`: exit 1. Exact error: `fatal: Unable to create 'C:/Users/User/Desktop/projects/NearMe/.git/worktrees/NearMe-p07a/index.lock': Permission denied`. The sandbox blocked the git metadata write. No commit was created.
  - This Windows machine has no Swift or Xcode. No Swift compilation, Xcode build, simulator test or real-phone test was run or claimed. App resource wiring and integration tests belong to P07.
- Mac test steps for the owner:
  1. After these changes are available in the Mac checkout, open Terminal at that checkout. Run `cd "$(git rev-parse --show-toplevel)"`, then `python3 scripts/validate-guides.py`. Expect `Validated 15 guides: 0 problems.` and exit 0. Run `git diff --check`; expect no whitespace errors.
  2. Run `for guide in NearMe/Resources/guides/*.json; do python3 -m json.tool "$guide"; done` to inspect each guide's steps and prerequisites. Use an English-language iPhone on the owner's installed iOS 26/27 version, with the installed WhatsApp version recorded. P07 has not bundled these files yet, so follow the JSON instructions directly on the phone.
  3. Check Settings guides: increase text size and confirm the sample grows; join a new protected home Wi-Fi network in Settings and confirm its connection tick; open Software Update and confirm the availability result without starting an installation.
  4. Check the three WhatsApp guides using an existing individual chat with a willing recipient and previously granted permissions: send one photo, start a video call, and record/send a voice message. Confirm whether the photo picker needs Next, and whether the upward gesture locks voice recording before the spoken-message step.
  5. Check Photos sharing through Messages, a FaceTime call, a new Contacts entry, and a text message with an existing contact. Match exact field capitalisation, recipient suggestions, save controls and final send/call controls against the checklist below.
  6. Check screenshots with a Face ID iPhone and full-screen previews enabled: make the single brief button gesture, save the result and confirm it exists in Photos. Compare thumbnail-preview behaviour and the documented Home button alternative if that device is available.
  7. Check Do Not Disturb starting with no Focus active, the torch starting off with its control on the first page, a regular alarm in both 12-hour and 24-hour time settings, and recent calls in Phone's Unified layout. Compare Classic layout and record the differences; restore settings after checking.
  8. For every flagged step below, record the actual label/control, order and result with the app/iOS version. Correct mismatches before clearing the flag, then rerun `python3 scripts/validate-guides.py`. No Xcode command is required for this content-only task; the owner's P07 Mac build and coach tests remain the integration gate.
- Not done / risks / questions:
  - Device verification is outstanding. The source notes document existing-chat/contact, permissions, starting-screen and layout prerequisites. The coach must not treat these drafts as universal paths for every layout or first-run setup state.
  - The screenshot's first hint names the physical buttons because the requested hardware path has no on-screen label at that point. This interpretation is explicitly documented in the schema notes instead of inventing an on-screen label.
  - P07's brief mentions a future `verified_on_device` field, but P07a's specified schema has no such field. None was added; P07 must resolve that integration detail if needed.
  - No prototype code was copied or adapted. No app code, build settings or project configuration was changed.
  - Everything remains uncommitted on `task/P07a-guides`, with content staged by the successful add and the final report/log edits unstaged. Per the owner's instruction, no retry or permission escalation was attempted. The manager must stage the final report/log and commit. One completion line was appended to `docs/LOG.md`; work stops here.

### Every flagged step to check on the phone

| Guide id | Step number | What to check |
|---|---|---|
| `add_contact` | 3 | Exact First name field wording/capitalisation and direct typing. |
| `add_contact` | 4 | Exact Last name field wording/capitalisation; optional entry. |
| `add_contact` | 5 | Exact add phone label and whether it reveals the number field. |
| `add_contact` | 6 | Exact Phone placeholder and number entry. |
| `add_contact` | 7 | Tick icon versus Done and whether it saves the contact. |
| `call_from_recents` | 2 | Calls tab in Unified layout; compare Recents in Classic layout. |
| `call_from_recents` | 3 | Phone icon beside the entry starts the intended call; compare tap-to-call settings. |
| `connect_wifi` | 5 | New protected network shows the password screen and exact Join control. |
| `facetime_contact` | 3 | Exact To: recipient field and direct name entry. |
| `facetime_contact` | 4 | Matching suggestion adds the intended FaceTime recipient. |
| `send_text_message` | 3 | Exact To: field in a new message. |
| `send_text_message` | 4 | Matching suggestion adds the intended message recipient. |
| `send_text_message` | 5 | Message box is available above the keyboard after recipient entry. |
| `set_alarm` | 4 | Hour wheel is present and can be changed independently. |
| `set_alarm` | 5 | Minute wheel is present and can be changed independently. |
| `set_alarm` | 6 | AM/PM wheel labels and choice in 12-hour mode; absence in 24-hour mode. |
| `set_alarm` | 7 | Displayed time clearly reflects the chosen morning/afternoon in both modes. |
| `set_alarm` | 8 | Tick icon versus Save/Done; saved alarm appears enabled. |
| `share_photo_from_photos` | 2 | Library tab opens the photo grid on the installed layout. |
| `share_photo_from_photos` | 5 | Messages is available in the sharing app row; note scrolling/order variations. |
| `share_photo_from_photos` | 6 | Exact To: field in the photo-sharing composer. |
| `share_photo_from_photos` | 7 | Suggestion adds the intended recipient without an extra confirmation. |
| `share_photo_from_photos` | 8 | Upward arrow sends the attached photo; its location in the composer. |
| `take_screenshot` | 2 | Full-screen preview has the tick save control and opens the expected menu. |
| `take_screenshot` | 3 | Exact Save to Photos option and saved image in Photos. |
| `turn_on_do_not_disturb` | 2 | Touch-and-hold on Focus opens the menu; compare an already active Focus. |
| `turn_on_torch` | 2 | Torch icon exists on the first page and turns on the light from off. |
| `turn_on_torch` | 3 | Bottom-edge swipe closes the controls while leaving the light on. |
| `whatsapp_send_photo` | 4 | Attachment plus icon location beside the message box. |
| `whatsapp_send_photo` | 5 | Photos versus Photo & Video Library label. |
| `whatsapp_send_photo` | 6 | Tapping one thumbnail reaches the preview; whether Next is required. |
| `whatsapp_send_photo` | 7 | Paper plane send icon on the preview and successful send. |
| `whatsapp_video_call` | 4 | Video camera icon at the top of an individual chat; any extra call confirmation. |
| `whatsapp_voice_message` | 4 | Upward gesture from microphone to padlock starts locked recording. |
| `whatsapp_voice_message` | 5 | Timer advances while the message is spoken with hands free. |
| `whatsapp_voice_message` | 6 | Paper plane icon sends the recording; no missing stop/preview action. |

## Review (round 1)
- Date: 2026-10-24 17:06 AEDT
- Verdict: PASS. Content only; merged to main. Owner checks the 36 `verify: true` steps on the iPhone (list in the Dev Report above).
- Manager read all 15 guides: one action per step, plain words, exact quoted labels, honest verify flags, Hinglish aliases on every guide, public URL schemes only (whatsapp://, sms:), no private Settings links, Wi-Fi password step as specified.
- Sources checked live: all 16 cited Apple and WhatsApp support URLs return 200 and resolve to the matching article (for example "Set an alarm in Clock on iPhone", "Use Unified layout in the Phone app on iPhone", "How to send voice messages | WhatsApp Help Center").
- `python scripts/validate-guides.py`: 15 guides, 0 problems.
- Nit for P07: a few "tap the name or chat" steps reuse a nearby label as `ui_label_hint` (connect_wifi step 4 "Wi-Fi", WhatsApp step 3 "Chats"); the coach must not tell the user to tap that label in those steps.
