---
id: obs-20260423-claude-settings-untracked
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- claude
- settings
- dotfiles
- git
- allowlist
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.090240+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-claude-settings-untracked

## content

~/.claude/settings.json is the global Claude allowlist config but lives outside any project repo. Changes to it are completely invisible to git status in any project, making it easy to lose across machine setups or forget to propagate to new environments.

## resolution

Track ~/.claude/settings.json in a dotfiles repo or explicitly document its contents in borg-collective infrastructure notes. When onboarding a new machine, this file must be manually restored.
