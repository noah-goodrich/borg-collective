---
id: obs-20260418-claude-settings-local-gitignore-gap
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude-code
- gitignore
- settings
- local-config
- security
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.045129+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-claude-settings-local-gitignore-gap

## content

.claude/settings.local.json was created this session but .gitignore has no entry for .claude/ or settings.local.json. This is a latent risk: a future `git add .` could commit local settings (which may contain secrets or machine-specific overrides) to the repo.

## resolution

Before committing the housekeeping batch, decide policy: at minimum add .claude/settings.local.json to .gitignore. Audit settings.json and settings.local.json contents first to confirm neither contains secrets before committing settings.json.
