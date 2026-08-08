---
id: obs-20260611-rename-reference-surface
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- hooks
- lifecycle
- refactor
- references
- spread
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.138699+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-rename-reference-surface

## content

A two-file hook rename in borg-collective touches more reference sites than expected: (1) hook file headers, (2) skill SKILL.md name/description fields, (3) borg.zsh cmd_setup registration calls (4 call sites: Claude + CoCo × SessionStart + Stop), (4) config/claude/settings.base.json, (5) live settings.json files in ~/.claude and ~/.snowflake/cortex, (6) live hooks/ and skills/ dirs in both tool homes, (7) README.md hook table + prose, (8) CLAUDE.md hook list + skills list, (9) install.sh instructions, (10) tool-count-nudge.sh nudge text, (11) borg.zsh help text (SKILLS section + CONFIG section), (12) lib/borg-hooks.sh comment, (13) skills/borg-review/SKILL.md and skills/borg-link/SKILL.md prose, (14) tests/cairn.bats + tests/lifecycle.bats variable assignments, (15) MEMORY.md index, (16) feedback_simplify_checkpoint.md.

## resolution

Use the exhaustive checklist from the Next Session plan. Do not rely on grep alone — some references are in comment strings and prose that grep patterns may miss.
