---
id: obs-20260616-skill-md-as-code-location
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- skill-md
- documentation
- drift
- mechanism-layer
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.506285+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-skill-md-as-code-location

## content

SKILL.md files in borg-collective act as a third implementation location for logic that is also in lib files — they contain inline prose descriptions of algorithms (e.g., the reaper predicate) that drift from the actual implementation. This creates a hidden maintenance surface that is easy to miss when refactoring.

## resolution

Replace inline algorithm prose in SKILL.md with a pointer to the canonical lib file (e.g., 'see `lib/reaper.sh`'). When doing any mechanism-layer extraction, treat SKILL.md as a code file that needs updating, not just documentation.
