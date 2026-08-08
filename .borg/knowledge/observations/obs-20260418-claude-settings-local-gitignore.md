---
id: obs-20260418-claude-settings-local-gitignore
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude-code
- gitignore
- secrets
- settings.local.json
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.267006+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-claude-settings-local-gitignore

## content

`.claude/settings.local.json` was created this session but `.gitignore` does not reference `.claude/` at all. This leaves open the risk that `settings.local.json` (which conventionally holds machine-local or secret overrides) gets committed accidentally on the next `git add .`.

## resolution

Before committing the housekeeping batch: inspect both `.claude/settings.json` and `.claude/settings.local.json` for secrets; add `settings.local.json` (or `.claude/settings.local.json`) to `.gitignore` if it contains any local-only or sensitive values. Commit `settings.json` only if it is safe to share.
