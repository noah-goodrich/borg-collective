---
id: obs-20260708-borg-resume-premise-falsified
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- borg-resume
- skill
- usage
- session-limits
- subprocess
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:25:36.252161+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-borg-resume-premise-falsified

## content

The shipped borg-resume skill asserts that session limits are 'not predictable from inside a session'. This premise is false. `claude -p '/usage'` reads server-authoritative usage data at zero token cost from any subprocess context, including scripts running outside the session.

## resolution

Correct the SKILL.md disclaimer. The limit is queryable via subprocess even if not exposed to hooks/workflows.
