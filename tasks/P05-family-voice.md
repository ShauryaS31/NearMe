# P05: Family voice (consented)

| Field | Value |
|---|---|
| Status | todo (after P04 and its Mac check) |
| Window | Sat 24 Oct |
| Depends on | P04 |
| Assignee | codex |
| Branch | task/P05-family-voice |

## Goal
The user can hear guidance in a familiar family member's voice, only with that person's recorded consent, always clearly labelled as an AI voice, and switchable off at any time.

## Read
AGENTS.md; docs/SPEC.md section 4; docs/design/HIG-NOTES.md rules 11, 12, 13. Files from P04: `ElevenLabsVoiceOutput`, voice cache and fallback, `APIKeys`, `NearMe/Info.plist`, `Secrets.xcconfig.example`, `Config/Base.xcconfig`, `NearMe/Views/Voice/`.

## Acceptance criteria
- [ ] Config: `ELEVENLABS_FAMILY_VOICE_ID` added to `Secrets.xcconfig.example` (empty), `Config/Base.xcconfig` (empty default) and `NearMe/Info.plist` (`$(ELEVENLABS_FAMILY_VOICE_ID)`); read in `APIKeys`
- [ ] Settings sheet opened by a gear button (SF Symbol `gearshape` plus "Settings" label, 44 x 44 pt) on the main voice screen. Voice picker: "Standard voice" or "Family voice". If the family voice id is empty, "Family voice" is shown disabled with "Not set up on this phone"
- [ ] Settings toggle "Natural voice (online)" bound to `VoiceSettings.naturalVoiceEnabled` (from P04), with the footnote "Off: NearMe uses the phone's own voice and nothing leaves your phone." When off, "Family voice" is disabled with "Needs Natural voice (online)" and the system voice speaks everything
- [ ] The first time "Family voice" is chosen, a consent screen appears before it takes effect. It states whose voice it is (required name field), that it is an AI copy of that person's voice made with their permission, and that it can be switched off at any time in Settings. Buttons: "Use this voice" (enabled only with a name and a checked "This person gave permission" toggle) and "Cancel" (stays on Standard voice). Shown once; afterwards switching is instant. "Change name" lives in Settings
- [ ] Choice, name and consent flag stored in `UserDefaults` (no other persistence)
- [ ] While the family voice is speaking, the session screens (voice and practice) show a small label "AI voice of <name>" that never covers the caption bar or primary buttons, with an accessibility label. Not shown when the standard or system voice speaks
- [ ] Family voice uses P04's caching (cache key includes the voice id) and fallback; the fallback speaks the line in the standard system voice and the label disappears for that line
- [ ] Tests (fakes, no network): consent required before the family voice is used; consent shown once; label text; voice selection maps to the right voice id; fallback clears the label

## Verify (Mac)
```
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh quick
```
Mac checks: Natural voice off gives the system voice for every line (no ElevenLabs entries in the voice log); switch voices; the label appears only for the family voice; consent shown once; switching back to Standard works.

<!-- Dev Reports and Reviews appended below. -->
