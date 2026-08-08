---
id: obs-20260616-gitignore-erroneous-borg-dir
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- gitignore
- dotborg
- untracked-files
- configuration
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.440346+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-gitignore-erroneous-borg-dir

## content

An erroneous `.borg/` line in .gitignore was causing the `.borg/` checkpoint directory to be ignored, which prevented session checkpoint files from being tracked. This landed as part of the deferred untracked files in PR #29.

## resolution

Removed the `.borg/` ignore rule. Added `.claude/` and `templates/supabase/.borg/` as intentional ignores. The distinction: the repo-root `.borg/` directory holds session state that should be tracked; tool config dirs like `.claude/` should not be.
