# N09: STRETCH: SCX fallback for hard goals

| Field | Value |
|---|---|
| Status | todo |
| Window | Only after N07 |
| Depends on | N03 |
| Assignee | codex |
| Branch | task/N09-scx |

## Goal
Enterprise and SCX prize angle.

## Read
AGENTS.md; docs/SPEC.md

## Acceptance criteria
- [ ] When the on-device planner asks for clarification twice, offer 'Ask online (Australia)'
- [ ] Send only the sanitised element list text and goal via SCXRuntime to an AU-region model; show what was sent
- [ ] Same validator applies to the answer

## Verify
```
xcodegen && xcodebuild -scheme NearMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

<!-- Dev Reports and Reviews appended below. -->
