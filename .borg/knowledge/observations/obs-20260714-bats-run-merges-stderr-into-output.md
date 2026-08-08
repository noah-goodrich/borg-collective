---
id: obs-20260714-bats-run-merges-stderr-into-output
session_date: '2026-07-14'
project: borg-collective
tool: claude-code
tags:
- bats
- testing
- stderr
- stdout
- json
- run
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-1747-borg-collective
superseded_by: null
created_at: '2026-07-14 17:49:55.811582+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-bats-run-merges-stderr-into-output

## content

bats `run some-command` captures both stdout and stderr into `$output` (and `$status`). Any unexpected stderr from the command under test — including bash-level errors like failed redirect opens — will be prepended or interleaved in `$output`, silently corrupting structured output such as JSON. The resulting error ('Invalid numeric literal at line 1, column N') gives no indication that the root cause is a bash redirect failure rather than a logic error in the JSON-producing code.

## resolution

When debugging bats failures with corrupt structured output, check for stray stderr by temporarily running the command outside bats or by inspecting the exact byte content of $output. Ensure all redirects in code under test are brace-grouped to prevent bash open-errors from leaking.
