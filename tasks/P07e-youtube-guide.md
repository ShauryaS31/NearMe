# P07e: YouTube guide (play a song)

| Field | Value |
|---|---|
| Status | in_progress |
| Window | Sat 24 Oct, target merged by 19:35 (venue closes 19:55) |
| Depends on | P11 |
| Assignee | codex (main folder, Lane A, highest priority) |
| Branch | task/P07e-youtube-guide |

## Goal
"Can you help me open YouTube and play this song" is coached step by step, with the song name in the steps, YouTube opened automatically, and the Live Activity following along. Minimal scope, one review round.

## Read
AGENTS.md; docs/design/GUIDES.md; one existing guide (`NearMe/Resources/guides/whatsapp_send_photo.json`) as a model. Files: `NearMe/Services/Intelligence/HelpRouter.swift` (keyword scoring, `HelpChoice`, person extraction), `CoachModelService.swift`, `FoundationModelsBrain` router `@Generable`, `NearMe/Services/CoachAppOpener.swift` (`CoachAppLaunch.url`), `NearMe/Info.plist`, `NearMe/ViewModels/TaskPlannerEngine.swift` (coach start, auto-open, follow-up question pattern from the trip flow), `NearMeTests/GuidedCoachTests.swift`.

Swift 6.4 rules: default arguments must not construct NearMe or test types or read MainActor statics; split long chains over tuples into typed steps; keep SwiftUI bodies small; use resolved stored properties, not optional init parameters.

## Acceptance criteria
- [ ] New guide `NearMe/Resources/guides/youtube_play_song.json` (validator passes): title "Play a song on YouTube", app "YouTube", `app_url_scheme` "youtube://", `last_checked` "2026-10-24", aliases include "play a song on youtube", "open youtube and play", "gaana chalao youtube pe", "youtube pe bhajan lagao", "play music on youtube", "youtube pe gaana chalao". Steps (max 6, one action each, icons, `verify: true` where unsure):
  1. `Open "YouTube".` (ui_label_hint "YouTube", icon "play.rectangle")
  2. Tap the search icon, the magnifying glass at the top right. (hint "search icon", icon "magnifyingglass", verify)
  3. `Type the song name.` (hint "Search YouTube", icon "keyboard", verify)
  4. Tap the search button on the keyboard. (hint "search", icon "magnifyingglass", verify)
  5. Tap the first result. (hint "first result", icon "list.bullet", verify)
  6. Tap play if it does not start by itself. (hint "play button", icon "play.fill", verify)
- [ ] Song name: the router's `@Generable` output gets an optional `song` field (like `person`); keyword fallback extracts it from "play <song> on youtube", "play the song <song>", "<song> on youtube", stripping filler; placeholders ("this song", "a song", "nil", "none") mean no song. The song is used in step 3 ("Type "Tum Hi Ho"." with the user's capitalisation) in the fallback text and as an instruction to the rewrite. Never stored beyond the session and never on the Lock Screen or Island (Live Activity keeps the guide's own text)
- [ ] Missing song: if the YouTube guide is chosen and no song is known, ask once "Which song would you like to play?" (spoken, Type instead works), take the answer (cleaned like a place answer) as the song, then continue the guide. If the answer is empty, continue with "Type the song name." unchanged
- [ ] Auto-open: add `youtube` to `LSApplicationQueriesSchemes`; add ("YouTube", "youtube://") to `CoachAppLaunch.url(for:)`; same rules and logging as WhatsApp (announce "I'll open YouTube for you now.", step 2 persisted before opening, "YouTube isn't on this phone." when not installed). Live Activity and Island alerts continue unchanged
- [ ] Router: keyword scoring routes "youtube", "song", "gaana", "bhajan", "music video" requests to `youtube_play_song`
- [ ] Tests (default run, fake brain and keyword fallback): "can you help me open youtube and play this song" routes to youtube_play_song with no song (asks the question); "play tum hi ho on youtube" routes with song "Tum Hi Ho" and step 3 contains it; "youtube pe gaana chalao" routes to youtube_play_song. The 8 existing acceptance phrases still pass. Validator: 16 guides, 0 problems

## Verify (Mac)
```
python scripts/validate-guides.py
bash scripts/mac-run.sh test --current
bash scripts/mac-run.sh device --current
```
iPhone check: "play tum hi ho on youtube": instant line, YouTube opens by itself at step 2, step 3 says to type "Tum Hi Ho", the Island follows each step.

<!-- Dev Reports and Reviews appended below. -->
