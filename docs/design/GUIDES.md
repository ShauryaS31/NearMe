# Guide library

P07a supplies 15 content files in `NearMe/Resources/guides/`. P07 will bundle and load them, route requests using their titles and aliases, and coach one step at a time. These files do not implement navigation or act inside another app.

The content review date is 24 October 2026. The guides target English interfaces on iOS 26/27 and WhatsApp for iPhone. `last_checked` records the documentation/editorial review, not a completed device test. No guide has been checked on a phone in this task. Uncertain steps carry `verify: true` for the owner's review.

## Schema and field meanings

Each file is a single JSON object, encoded as UTF-8 without a byte-order mark, with two spaces per indentation level and a final newline. Use literal Unicode rather than escaped non-ASCII text. LF and CRLF line endings are accepted. Unknown fields and duplicate JSON keys are rejected.

```json
{
  "id": "iphone_text_bigger",
  "title": "Make the writing bigger on iPhone",
  "app": "Settings",
  "aliases": [
    "how do i make the writing bigger",
    "bigger text",
    "make the letters larger on my phone",
    "i cannot read the small writing",
    "increase the text size",
    "make my iphone easier to read",
    "text bada karna hai",
    "phone ki writing badi karo"
  ],
  "steps": [
    {
      "instruction": "Open \"Settings\".",
      "ui_label_hint": "Settings"
    },
    {
      "instruction": "Tap \"Display & Brightness\".",
      "ui_label_hint": "Display & Brightness"
    },
    {
      "instruction": "Tap \"Text Size\".",
      "ui_label_hint": "Text Size"
    },
    {
      "instruction": "Drag the slider to the right until the sample writing is easy to read.",
      "ui_label_hint": "text size slider"
    }
  ],
  "source_note": "Settings on iOS 26/27, English. Alternative: Accessibility > Display & Text Size > Larger Text. Documentation review only.",
  "last_checked": "2026-10-24"
}
```

| Field | Type and requirement | Meaning |
|---|---|---|
| `id` | Required non-empty string | Unique snake_case identifier, equal to the filename without `.json`. Use exactly the P07a identifiers below. |
| `title` | Required non-empty string | Short, plain description of the outcome. |
| `app` | Required non-empty string | The app the user starts in, or the system surface: `iPhone` for screenshots and `Control Centre` for torch and Focus. |
| `app_url_scheme` | Optional non-empty string | Publicly documented launch scheme. See the restrictions below. Omit the key rather than using `null` or an empty value. |
| `aliases` | Required array of 6 to 10 distinct, non-empty strings | Lowercase ways someone might ask, including plain English, a short request and at least two natural Hinglish or simple mixed phrasings. |
| `steps` | Required array of 3 to 8 step objects | Ordered actions. Do not join two independent taps to fit the limit. |
| `steps[].instruction` | Required non-empty string | One action, at most two short sentences. Keep within 200 characters for P07's coach; each sentence is limited to 25 words by this validator. |
| `steps[].ui_label_hint` | Required non-empty string | Exact English screen label, preserving case and punctuation, or a plain description of an icon/control such as `microphone icon`. Do not include surrounding quote marks in the value. |
| `steps[].verify` | Optional JSON boolean | `true` means the wording, control, position or order needs a phone check. Omission and `false` do not certify device verification. |
| `source_note` | Required non-empty string | App and version/layout, language, prerequisites, known variations, and provenance. Keep alternative paths here rather than mixing them into the main steps. |
| `last_checked` | Required date string | Exactly `2026-10-24` for this task. |

All text fields must be single-line strings without surrounding whitespace. Arrays and booleans must use real JSON types, not string representations.

### Fixed library and schemes

| Guide id | Starting app/surface | Optional scheme |
|---|---|---|
| `whatsapp_send_photo` | WhatsApp | `whatsapp://` |
| `whatsapp_video_call` | WhatsApp | `whatsapp://` |
| `whatsapp_voice_message` | WhatsApp | `whatsapp://` |
| `iphone_text_bigger` | Settings | Omit |
| `connect_wifi` | Settings | Omit |
| `take_screenshot` | iPhone | Omit |
| `share_photo_from_photos` | Photos | Omit |
| `facetime_contact` | FaceTime | Omit |
| `add_contact` | Contacts | Omit |
| `turn_on_do_not_disturb` | Control Centre | Omit |
| `check_ios_update` | Settings | Omit |
| `set_alarm` | Clock | Omit |
| `call_from_recents` | Phone | Omit |
| `turn_on_torch` | Control Centre | Omit |
| `send_text_message` | Messages | `sms:` |

WhatsApp documents its [custom URL scheme](https://faq.whatsapp.com/425247423114725/?cms_platform=iphone). Apple documents the [Messages scheme](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/SMSLinks/SMSLinks.html). No recipient, message text, credential or other query data belongs in these values. A future number-dialling guide may use a documented `tel:` scheme, but none of these 15 guides dials a supplied number; the Phone guide opens an existing call entry. The validator therefore rejects `tel:` for this library. Settings, Photos, Clock, Contacts, Phone, FaceTime and Control Centre have no launch scheme here. Private or undocumented URLs, including `App-prefs:`, are forbidden.

### Labels and the coach

Every on-screen text label used in an instruction must be inside straight double quotes and match a `ui_label_hint` in that same guide exactly. For example, `Tap "Text Size".` requires the hint `Text Size`. A hint in another guide does not count. Icons can be described without quotes; their hints use the same plain descriptions.

Use a stable heading such as `Chats`, `Wi-Fi` or `To:` to orient steps that involve a person's name or a network chosen by the user. Never invent a person's name, network name or example account to put into a hint. Photo thumbnails, time wheels and message boxes are visual controls rather than fixed text labels.

The screenshot gesture necessarily targets physical buttons. Its first hint names those buttons explicitly; it does not pretend they are an on-screen label. This is a documented interpretation of the task's hardware screenshot path. All other hints refer to screen text, icons or controls.

P07's model has no tools. It may rephrase a step but must preserve quoted labels from this guide's hints; it cannot invent labels. P07's runtime validator also limits rewrites to two sentences and 200 characters. If rewriting fails, the original instruction is used. The guide content must remain usable without a model rewrite. `verify: true` is intended to show a small check-on-screen note in Debug builds; it is not a replacement for device review.

## Writing and review rules

1. Write one action per step using familiar words such as tap, swipe, type or drag. A second sentence may explain the result, but must not hide another action. A quick simultaneous button press is one gesture; never split it into a press step and a later release step in a paced coach.
2. Use at most two short sentences. Avoid jargon, `select`, `click`, technical control names and unexplained abbreviations. Do not rely only on colour to identify a control.
3. Quote screen labels exactly, including case and punctuation. Use real icons or stable screen headings for variable content. Do not make up labels just to satisfy the quote validator.
4. Prefer a single common path. Describe prerequisites and layout variations in `source_note`. Control Centre uses a downward swipe from the top-right corner on Face ID iPhones. Note the Home button alternative where relevant.
5. Mark every uncertain label, position or sequence with `verify: true`. A cited help article supports a draft; it does not establish that every iOS 26/27 release or installed WhatsApp version matches. If a phone shows a different path, revise the steps before treating the guide as ready.
6. Use 6 to 10 lowercase aliases that sound like real requests. Include at least two Hinglish/mixed requests, some plain English, and a short form. Avoid padding with identical phrasings or jargon.
7. Do not include person names, invented features, prices, sample account details or brands other than the relevant Apple apps and WhatsApp. Use metric units where needed and no em dashes.
8. Never request a password or code in NearMe. The Wi-Fi guide enters the password in Settings and uses exactly `Type the Wi-Fi password, then tap "Join".` with nothing added. This sentence is the task's explicit exception to the one-action rule. The path assumes a new protected home network, not a public sign-in page.
9. Review the whole path for completion: the photo/message is sent, the contact/alarm is saved, or the requested setting is on. The update guide stops after checking availability. Account setup, permissions, troubleshooting and alternate layouts are not additional hidden steps.
10. Review spoken pacing as well as the screen. The locked voice recording gesture avoids requiring someone to hold a button between coach steps. The owner must confirm that gesture and its send control on the installed WhatsApp version.

## Validation

From the repository root:

```sh
python scripts/validate-guides.py
```

On a Mac where Python is called `python3`, use `python3 scripts/validate-guides.py`. The script also works when invoked by its absolute path from another directory. It needs only Python 3's standard library and does not write files.

Successful output is `Validated 15 guides: 0 problems.` with exit status 0. Failures print one line per detected problem with the filename and field/step where available, then exit with status 1. Missing files and unexpected entries also fail. Malformed JSON, duplicate keys, invalid UTF-8, a byte-order mark and non-JSON constants are rejected.

The script checks field names/types, required strings, exact ids and filenames, app mapping, scheme restrictions, counts, duplicate aliases, date, formatting, label membership, balanced quotes, sentence/character limits, obvious compound actions, password wording, jargon, em dashes, curly quotes, private Settings URLs, price markers and imperial units. Hinglish detection uses a small vocabulary heuristic; the presence of a matching word does not prove that an alias is natural. A conservative capitalisation check flags possible names/brands or unsupported labels in instructions.

Human review remains required for exact UI accuracy, natural Hinglish, unquoted screen labels, names/brands and invented account details in prose, truthful provenance, complete action sequences and whether every uncertain step was flagged. Passing the script is not device verification. The Dev Report lists each flagged step separately for the owner. No Swift, Xcode, model or app tests are required by this content-only task; P07 owns integration and its Mac tests.

## How to add or revise a guide

1. For P07a, use only the fixed 15 ids above. A later task must explicitly authorise any additional id and update `EXPECTED_APPS` in the validator, this table and P07's loader/tests together.
2. Read current official documentation for the target app and record a supporting URL and the actual layout in `source_note`. State if documentation could not be retrieved. Do not claim a phone check that did not happen.
3. Write the JSON using the schema, with 6 to 10 aliases and 3 to 8 steps. Check that every quoted instruction label appears verbatim in this guide's hints. Add only a permitted launch scheme.
4. Mark uncertainty before review. Follow every step on an English-language phone, starting from the documented state. Check variant layouts on supported devices; repair wording or ordering that differs. Clear a flag only after checking the specific uncertainty and recording the device/app version and result in the task report. Do not add undocumented schema fields.
5. Run the validator, review the actual diff, and include the output and remaining flagged steps in the task's Dev Report. Have the owner check the phone path before P07 integration relies on it.

## Source map

These are documentation sources, not claims of device testing. Each guide's `source_note` also records its provenance and limitations.

| Guides | Official source |
|---|---|
| WhatsApp photo | [Send media on iPhone](https://faq.whatsapp.com/453914586839706/?cms_platform=iphone) |
| WhatsApp video call | [iPhone video call help](https://faq.whatsapp.com/iphone/voice-and-video-calls/how-to-make-a-video-call/), not retrievable during this review; call control flagged |
| WhatsApp voice message | [Voice message help](https://faq.whatsapp.com/657157755756612/?cms_platform=iphone), iPhone content not retrievable during this review; recording path flagged |
| Bigger text | [Display and text settings](https://support.apple.com/guide/iphone/iphd6804774e/26/ios/26) |
| Wi-Fi | [Connect to Wi-Fi](https://support.apple.com/en-ie/111107) |
| Screenshot | [Screenshot controls on iOS 26](https://support.apple.com/en-au/guide/iphone/iphc872c0115/26/ios/26) |
| Share a photo | [Share photos](https://support.apple.com/en-nz/guide/iphone/iphf28f17237/27/ios/27) |
| FaceTime | [Make FaceTime calls](https://support.apple.com/en-euro/guide/iphone/iph7801d5771/26/ios/26) |
| Add a contact | [Add contact information](https://support.apple.com/en-au/guide/iphone/iph3e0ca2db/26/ios/26) |
| Do Not Disturb | [Focus menu controls](https://support.apple.com/en-gb/105112) |
| Check for updates | [Software Update](https://support.apple.com/en-ie/118575) |
| Set an alarm | [Clock alarms](https://support.apple.com/guide/iphone/iph2909d3a74/27/ios/27) |
| Recent calls | [Unified and Classic Phone layouts](https://support.apple.com/en-tm/126076) |
| Torch | [Torch controls](https://support.apple.com/en-au/guide/iphone/iphf574afb44/26/ios/26) |
| Text message and photo recipient | [Messages](https://support.apple.com/guide/iphone/iph82fb73ba3/26/ios/26) |
