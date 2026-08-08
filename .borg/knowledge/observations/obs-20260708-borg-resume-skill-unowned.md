---
id: obs-20260708-borg-resume-skill-unowned
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- borg-collective
- skills
- source-of-truth
- technical-debt
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:25:36.251645+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-borg-resume-skill-unowned

## content

`borg-resume` skill is installed at `~/.claude/skills/borg-resume/SKILL.md` with no corresponding source under `borg-collective/skills/`. It is unowned by the canonical repo, violating the source-of-truth rule. It also contains a now-false disclaimer stating session limits are 'not predictable from inside a session'.

## resolution

Import the skill into `borg-collective/skills/` and correct the disclaimer to reference the usage guardian. Tracked in `docs/plans/directives/2026-07-08-usage-guardian-build.md` under 'Also do'.
