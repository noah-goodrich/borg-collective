---
id: obs-20260714-json-concat-bats-only-failure
session_date: '2026-07-14'
project: borg-collective
tool: claude-code
tags:
- bats
- jq
- json
- borg-link-down
- additionalContext
- hooks
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-1733-borg-collective
superseded_by: null
created_at: '2026-07-14 17:34:17.054322+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-json-concat-bats-only-failure

## content

borg-link-down.sh's project-mode JSON output is valid when run manually against a normal project directory, but fails BATS tests 12/14/15 with `jq: parse error: Invalid numeric literal at line 1, column 88`. The failure is triggered exclusively when BATS fixtures activate multiple additionalContext branches simultaneously (has_uncommitted_changes=true in state.json AND PROJECT_PLAN.md present). The root cause is that the additionalContext string is concatenated into the JSON via printf interpolation rather than via `jq --arg`, so special characters in the concatenated string corrupt the JSON structure.

## resolution

Assemble the full additionalContext string in a bash variable first, then pass it into the jq filter via `--arg`. Add a BATS regression test that activates all context branches at once and validates output with `jq .`.
