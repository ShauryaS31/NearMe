# The Software Factory: how agents work in this repo

Claude Code is the **manager and reviewer**. Codex (gpt-6-astra) is the **developer**. Shaurya is the **owner**: approves milestones, tests on the real device, holds the keys.

All state lives in files, so any agent can be restarted with zero memory and pick up where things stopped.

## Files

| File | Who writes | Purpose |
|---|---|---|
| `docs/SPEC.md` | Owner, Manager (with approval) | What we are building. Source of truth |
| `docs/PLAN.md` | Manager | Dated milestones and the task board (status table) |
| `docs/LOG.md` | Everyone, append only | Dated, timestamped record of every dispatch, report, review, merge |
| `tasks/Nxx-*.md` | Manager writes the brief and reviews; Developer writes Dev Reports | One file per task. The full brief. Developer needs nothing else |
| `CLAUDE.md` | Owner | Manager instructions (Claude Code reads it automatically) |
| `AGENTS.md` | Owner | Developer instructions (Codex reads it automatically) |

Why one file per task and not one big shared doc: two agents editing the same file causes overwrites and merge conflicts, and every agent would load the whole history into context. A task file holds only what that task needs.

## Statuses

`todo` > `in_progress` > `in_review` > `changes_requested` (loops back to `in_progress`) > `done`
Also `blocked` (needs owner) and `dropped`.

## The loop

```
Manager                                     Developer (fresh process each time)
-------                                     ----------------------------------
1. Pick next task: first `todo` in PLAN.md
   whose dependencies are all `done`
2. Check the brief is complete. Set
   `in_progress`. Create branch
   task/Nxx-slug from main. LOG entry.
3. Dispatch:  codex exec ... "Do task Nxx"  -->  Reads AGENTS.md + tasks/Nxx.md only
                                                Implements on the branch
                                                Runs the task's verify commands
                                                Appends "Dev Report (round n)"
                                                Commits, appends LOG line, exits
4. Review (in a review subagent if the diff
   is large, to keep the manager's context
   small):
   - git diff main...task/Nxx
   - run verify commands yourself
   - check every acceptance criterion
   - check SPEC rules (no tools in reader,
     no secrets, Core has no platform imports)
   Write "Review (round n)" with verdict.
5a. PASS: merge to main (no fast-forward),
    status `done`, LOG entry, go to 1.
5b. CHANGES: list exact numbered fixes,
    status `changes_requested`, go to 3
    (new Developer process, same branch).
5c. Round 3 still failing, or needs device,
    keys, accounts or a product decision:
    status `blocked`, notify owner, move
    on to another task.
6. End of milestone: STOP and ask owner for
   the milestone gate (device test).
```

## Context hygiene

- The Developer never sees the chat. If it is not in the task file, AGENTS.md or the repo, it does not exist.
- One `codex exec` process per round. It exits when done, so its context is thrown away.
- The manager keeps only the board in its head. For a fresh start: read `docs/PLAN.md` and the last 30 lines of `docs/LOG.md`. Use `/clear` (or a new Claude Code session) after each milestone.
- The manager reviews big diffs through a subagent and keeps only the verdict.

## Two machines

```
Windows (factory)                      GitHub                        Mac (owner)
Claude Code + Codex write code  --push-->  main + task branches  --pull-->  scripts/mac-run.sh
CI (macos-26), manual only     <------ workflow_dispatch                  builds, launches NearMe
                                                                          owner runs checklist
Manager reads results  <--pull-- docs/mac-results/YYYY-MM-DD-HHMM.md <--push-- owner (or tells manager)
```

- Only Windows edits code, with one exception: the Mac may push compile-only fixes to main as `macfix:` commits (see CLAUDE.md), which the manager reviews on resume. Otherwise the Mac only adds files under `docs/mac-results/`. This avoids merge conflicts.
- Gate per task: owner Mac checks pass (CI is manual only, run on request).

## Gates
1. Owner Mac checks pass on the task branch (`scripts/mac-run.sh --current`, simulator and iPhone when available).
2. Every acceptance criterion checked with evidence, or marked PENDING MAC with exact test steps.
3. No secrets in the diff.

## Watching Codex
`Get-Content logs/current.log -Wait -Tail 50` in a second pane.
