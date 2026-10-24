# N07: Grounding benchmark and demo tasks

| Field | Value |
|---|---|
| Status | todo |
| Window | Sat 24 Oct 19:00 to 20:00 |
| Depends on | N02 |
| Assignee | codex, then owner |
| Branch | task/N07-benchmark |

## Goal
Real numbers for the judges.

## Read
AGENTS.md; docs/SPEC.md

## Acceptance criteria
- [ ] Scripted runs: 3 System Settings goals (text size, Dark Mode, Wi-Fi details) x 5 runs each; log first-step correctness, steps to completion, latency per step to logs/benchmark.csv
- [ ] Owner reviews and pastes the summary into LOG
- [ ] Pick the two demo tasks with the best reliability

## Verify
```
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
