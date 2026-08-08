---
id: obs-20260417-settings-local-json-commit-decision
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude
- settings
- gitignore
- local-overrides
- workspace-config
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.037417+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260417-settings-local-json-commit-decision

## content

`.claude/settings.local.json` was created alongside `.claude/settings.json` but its contents were not inspected. The question of whether it should be committed or gitignored was explicitly deferred.

## resolution

Establish a convention: `settings.json` (shared workspace config) is committed; `settings.local.json` (machine/user-specific overrides) is gitignored — analogous to `.env` vs `.env.local`. Add `settings.local.json` to `.gitignore` unless there's a specific reason to share local overrides.
