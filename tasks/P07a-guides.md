# P07a: Guide library content (15 guides, content only)

| Field | Value |
|---|---|
| Status | in_progress |
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
