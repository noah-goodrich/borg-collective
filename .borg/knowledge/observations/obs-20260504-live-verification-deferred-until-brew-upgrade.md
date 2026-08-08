---
id: obs-20260504-live-verification-deferred-until-brew-upgrade
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-setup
- brew
- skill-extensions
- deployment-gap
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.301227+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260504-live-verification-deferred-until-brew-upgrade

## content

Edited SKILL.md files in the repo do NOT take effect in Claude Code until `brew upgrade borg-collective && borg setup` runs. The setup command is what copies skills to `~/.claude/skills/`. A session can ship a PR with protocol changes that appear complete but are entirely unverified because the local Claude environment is still running the pre-upgrade SKILL.md.

## resolution

Always include live verification as an explicit post-merge step. Use `grep -c 'Local Extensions:' ~/.claude/skills/<skill>/SKILL.md` after `borg setup` to confirm the new load points are present before attempting any extension-dependent workflow.
