---
id: obs-20260511-dev-cleanup-disk-reclaim
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- disk-space
- cleanup
- dev-environment
category: performance
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.370197+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260511-dev-cleanup-disk-reclaim

## content

~/dev directory accumulated ~9.78G of stale repos and scaffolds (sfquickstarts: 9.3G alone). Snowflake quickstarts clones are particularly large and frequently left behind after POC work.

## resolution

Archived to ~/Documents/old-repos/ or deleted. GitHub-archived noah-goodrich/SnowDDL and snowflake-examples to signal inactive status. Add a periodic ~/dev audit to borg session hygiene checklist.
