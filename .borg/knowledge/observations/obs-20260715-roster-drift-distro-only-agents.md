---
id: obs-20260715-roster-drift-distro-only-agents
session_date: '2026-07-15'
project: borg-collective
tool: claude-code
tags:
- agent-roster
- source-of-truth
- drift
- claude-plugins
- distro
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260715-0256-borg-collective
superseded_by: null
created_at: '2026-07-15 02:57:12.427595+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-roster-drift-distro-only-agents

## content

Five agents (borg-grunt, borg-scout, ROUTING, borg-researcher, borg-reviewer) existed only in the claude-plugins distro and had no corresponding source files in agents/. Any change to these agents made in agents/ would be silently dropped on the next sync; any change made directly in the distro would be unreproducible from source. The drift was not detectable without an explicit guard script.

## resolution

Back-ported all five agents to agents/ (PR #79). Added scripts/check-agent-roster.sh drift guard and tests/agent_roster.bats (5 tests, negative-tested). Directive moved to assimilated.
