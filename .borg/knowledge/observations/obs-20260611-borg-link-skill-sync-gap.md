---
id: obs-20260611-borg-link-skill-sync-gap
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bash-guard
- skill-sync
- installed-copy
- claude-home
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.422500+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-borg-link-skill-sync-gap

## content

There are two copies of each skill's SKILL.md: the source-of-truth in the borg-collective repo and the installed copy at ~/.claude/skills/. bash-guard correctly prevents Claude from writing to ~/.claude/, which means every time a SKILL.md is updated in the repo, the installed copy silently goes stale. There is no automated sync step in the release cycle.

## resolution

After any release that modifies a SKILL.md, manually run: cp /path/to/borg-collective/skills/<skill>/SKILL.md ~/.claude/skills/<skill>/SKILL.md. This should be added as an explicit checklist item in the release process.
