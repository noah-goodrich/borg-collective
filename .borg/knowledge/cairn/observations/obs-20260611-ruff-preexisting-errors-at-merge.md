---
id: obs-20260611-ruff-preexisting-errors-at-merge
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- ruff
- lint
- ci-gate
- technical-debt
category: tool_behavior
files_involved: []
confidence: 0.8
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.726968+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-ruff-preexisting-errors-at-merge

## content

The assimilate gate ran cairn-lint and surfaced 23 pre-existing ruff errors that had accumulated on the feature branch (unused imports, unused variable 'func', C901 complexity on build_mcp_server). These were not introduced in this session but had to be fixed before the gate would pass.

## resolution

Fixed via ruff autofix plus a manual noqa comment for the C901 case. Ran cairn-format on 20 files as a follow-up. All 174 tests passed after cleanup. Consider running lint as a pre-commit hook or in CI on every branch push to catch these earlier.
