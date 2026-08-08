---
id: obs-20260616-borg-link-down-capacity-mismatch
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg
- reaper
- capacity
- link-down
- consistency
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.494107+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-borg-link-down-capacity-mismatch

## content

borg-link-down.sh was using a different capacity scan logic than the CLI reaper, causing the hook-triggered reap to produce different capacity numbers than borg status/borg next after a link-down event.

## resolution

borg-link-down.sh capacity scan was updated to match the CLI logic. When duplicating reaper logic across CLI and hook contexts, add an explicit test that both paths produce identical capacity counts for the same registry state.
