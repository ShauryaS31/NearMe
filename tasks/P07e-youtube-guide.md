# P07e: YouTube guide (play a song)

| Field | Value |
|---|---|
| Status | done (iPhone PASS) |
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

## Dev Report (round 1)
- Date: 2026-10-24 19:15 AEDT
- Changed files: `NearMe/Resources/guides/youtube_play_song.json`; `NearMe/Models/SongNormalization.swift`; `NearMe/Models/CoachSession.swift`; `NearMe/Models/HelpGuide.swift`; `NearMe/Services/Intelligence/HelpRouter.swift`; `NearMe/Services/Intelligence/CoachModelService.swift`; `NearMe/Services/Intelligence/GuideLibrary.swift`; `NearMe/Services/CoachAppOpener.swift`; `NearMe/Info.plist`; `NearMe/ViewModels/TaskPlannerEngine.swift`; `NearMe/Views/Components/SessionDock.swift`; `NearMe/Views/Voice/VoiceSessionView.swift`; `NearMe/Services/Speech/VoiceOutputService.swift`; `NearMe/Services/Speech/ElevenLabsVoiceOutput.swift`; `NearMeTests/GuidedCoachTests.swift`; `NearMeTests/CoachAppOpenTests.swift`; `NearMeTests/CoachLiveActivityTests.swift`; `NearMeTests/ModelAvailabilityTests.swift`; `NearMeTests/ElevenLabsVoiceOutputTests.swift`; `scripts/validate-guides.py`; `docs/design/GUIDES.md`; this task file; `docs/LOG.md` (completion entry).
- What I did: Added the six-step YouTube guide, keyword routing, optional generated song field, session-only song personalisation, one follow-up question, and YouTube launch allowlisting. The generated help router lives in `CoachModelService.swift`; the separate journey-only `FoundationModelsBrain.swift` needed no changes. Reused the existing app handoff, persistence and Live Activity paths. Empty typed answers are enabled only while waiting for a song. Personal song speech uses system speech to avoid the existing persistent ElevenLabs audio cache. No new default arguments construct app/test types or read actor-isolated statics; project build settings are unchanged.
- Acceptance criteria:
  1. Guide: exact title, app, scheme, date, six required aliases, six actions/hints/icons; steps 2, 3, 4, 5 and 6 retain `verify: true`. Both library validators accept the new ID and scheme. Python validator passes with 16 guides.
  2. Song: `HelpChoice` and `GeneratedHelpChoice` carry an optional song. Fallback handles the three required English patterns, filler and placeholders. All-lowercase transcripts become title case (Tum Hi Ho); supplied mixed capitalisation is preserved. Step 3 fallback and rewrite receive the title. Rewrite validation permits that exact title as user content while rejecting invented quoted titles. The song is absent from saved progress, restored sessions, Live Activity snapshots and alerts. Personalised speech bypasses disk audio caching.
  3. Missing song: asks and speaks exactly "Which song would you like to play?" once, follows the existing listening pattern, supports switching to Type instead, cleans the answer, and continues with unchanged generic step 3 for empty input/no speech. Stop/end clears the pending question.
  4. Auto-open: added `youtube` to Info.plist and the exact YouTube scheme pair to the launch allowlist. Existing announcement, step-2 persistence/flush before opening, not-installed explanation, rollback, diagnostics and Island alert logic are reused.
  5. Router: youtube/song/gaana/bhajan/music video keyword matches select `youtube_play_song`; explicit request extraction survives model-to-keyword override.
  6. Tests: added default-run fake-model and no-model cases for all three required requests, extraction variants, placeholders/capitalisation, accepted/rejected rewrites, one-time question, typed/voice/empty answers, cancellation, app handoff ordering, missing app, generic activity alerts, restored-session privacy and audio-cache avoidance. Existing acceptance tests are retained. XCTest execution remains pending on the owner's Mac; no pass is claimed here.
- Verify commands run and results: `python scripts/validate-guides.py` => `Validated 16 guides: 0 problems.` (exit 0). `git diff --check` => exit 0, only existing CRLF-to-LF notices for the two edited views. An inline Python `plistlib`/JSON assertion check passed for the query scheme, six steps, generic song-entry text and verification flags. `Get-Command swift,xcodebuild -ErrorAction SilentlyContinue` found neither tool. This Windows machine has no Swift or Xcode; the Mac test/device commands were not run. `rg` is unavailable, so file searches used PowerShell.
- Mac test steps for the owner:
  1. With the manager's P07e changes present on `task/P07e-youtube-guide`, run `python3 scripts/validate-guides.py` from the repository root; expect 16 guides, 0 problems.
  2. Run `bash scripts/mac-run.sh test --current`; inspect the new GuidedCoach, CoachAppOpen and ElevenLabsVoiceOutput tests plus existing routing/Live Activity regressions. The helper regenerates the Xcode project for the new Swift/JSON files. Do not commit the generated project.
  3. Connect the iPhone with YouTube installed and run `bash scripts/mac-run.sh device --current`.
  4. Say "play tum hi ho on youtube". Confirm the immediate acknowledgement, "I'll open YouTube for you now.", automatic opening at step 2, step 3 in NearMe saying `Type "Tum Hi Ho".`, and Island progress at each step. Song-containing speech intentionally uses system voice. Lock Screen/Island step 3 must remain "Type the song name.".
  5. End the session. Say "can you help me open youtube and play this song"; answer the single song question by voice, then repeat using Type instead. Repeat with an empty typed answer and confirm generic step 3. Also try "youtube pe gaana chalao" and verify routing/question.
  6. Verify flagged steps separately: search icon position (2), search input (3), keyboard search button (4), first result (5), play control/autoplay (6). Confirm Island alerts stay generic. Restart NearMe at step 3 and confirm the song is not restored. On a simulator/device without YouTube, confirm "YouTube isn't on this phone." and no skipped opening step.
- Not done / risks / questions: Swift 6.4 compilation, default XCTest run, real-model behaviour and phone UI verification require the Mac. Search/result layout and ads may vary. Existing LOG.md records unrelated SessionLayoutTests/VoiceReviewTests failures; they were not changed under P07e. `docs/ui-mockups/` and P12 work were not touched.
- Commit result: `git add -- <explicit P07e files>` succeeded and `git diff --cached --check` reported no whitespace problems. `git commit -m "P07e: add session-private YouTube song coaching and auto-open"` failed: `fatal: Unable to create 'C:/Users/User/Desktop/projects/NearMe/.git/index.lock': Permission denied`. Git metadata writes are restricted by the sandbox. Everything remains uncommitted; the earlier staging succeeded, while this report correction and the final LOG.md entry are unstaged. The manager must stage those updates and commit. Stopped without retrying, merging or starting another task.

## Review (round 1)
- Date: 2026-10-24 19:16 AEDT
- Verdict: PASS (static, one urgent round). Merged to main (Lane A first).
- Guide youtube_play_song valid (16 guides, 0 problems); youtube in LSApplicationQueriesSchemes and CoachAppLaunch; song extracted (model field plus keyword fallback, placeholders ignored) and used in step 3; "Which song would you like to play?" asked once when missing, empty answer continues unchanged; lines containing a song title use the system voice so personal titles never enter the ElevenLabs cache; Live Activity keeps guide text only. Default-argument scan clean.
