---
id: obs-20260616-bats-fixture-reaper-centralization
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- bats
- testing
- fixtures
- refactoring
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.505931+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-bats-fixture-reaper-centralization

## content

When centralizing a function that was previously inlined in multiple lib files, existing bats fixtures that stub or source those lib files break if they set up state assuming the function is defined locally. Two fixtures in `tests/state.bats` broke this way after reaper centralization.

## resolution

Updated fixtures to source `lib/reaper.sh` explicitly, or to source the updated consumer files that now delegate to it. When centralizing functions, search test fixtures for direct references to the old locations — not just the source files.
