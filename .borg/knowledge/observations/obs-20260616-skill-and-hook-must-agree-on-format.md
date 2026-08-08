---
id: obs-20260616-skill-and-hook-must-agree-on-format
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- hooks
- skills
- adhd-guardrails
- coupling
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.420954+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-skill-and-hook-must-agree-on-format

## content

When a hook injects a warning that a skill is supposed to respond to, the warning format (e.g., '⚠ CAPACITY WARNING') must be explicitly documented in the skill so the skill's instructions can reference it unambiguously. If the hook output format changes, the skill behavior silently breaks.

## resolution

adhd-guardrails SKILL.md now includes a Capacity Management section that names the exact warning string and defines the expected response. Treat hook output format as an API contract between hook and skill.
