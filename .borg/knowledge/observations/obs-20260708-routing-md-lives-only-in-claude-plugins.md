---
id: obs-20260708-routing-md-lives-only-in-claude-plugins
session_date: '2026-07-08'
project: borg-collective
tool: claude-code
tags:
- routing
- claude-plugins
- source-of-truth
- repo-structure
category: gotcha
files_involved: []
confidence: 0.8
source_model: null
source_session: 20260708-1940-orchestrator
superseded_by: null
created_at: '2026-07-08 19:41:01.407612+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-routing-md-lives-only-in-claude-plugins

## content

claude-plugins/borg-collective/agents/ROUTING.md is the authoritative location for model routing rules. The borg-collective source repo has NO agents/ROUTING.md — the agents/ directory is native to claude-plugins and is not synced from borg-collective. This means edits to ROUTING.md in claude-plugins are not at mirror-overwrite risk, but the split creates confusion about which repo is the source of truth for agents/ content.

## resolution

Confirm the intended ownership of agents/ in the project's repo structure documentation. Until clarified, treat claude-plugins/borg-collective/agents/ as the authoritative location and do not create a parallel agents/ in the borg-collective source repo.
