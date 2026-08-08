---
id: lifecycle-inversion-end-to-end-checklist
project: borg-collective
domain: architecture
tags:
- lifecycle
- hooks
- refactoring
- settings-json
- tests
preconditions: []
steps:
- Rename hook shell scripts via .swap intermediate
- Flip header comments and internal cross-references inside each script
- Update the orchestrator (borg.zsh cmd_setup) — all registration blocks (Claude,
  CoCo, etc.)
- Update config/claude/settings.base.json hook arrays
- Update live env settings files (~/.claude/settings.json, ~/.snowflake/cortex/settings.json)
- Install/copy updated hook scripts to live hook directories
- Verify all three settings JSONs with `jq empty` and `jq .hooks`
- Update skills directory name and SKILL.md metadata
- Copy updated skill to live skills directory; remove old skill directory
- Update all doc files referencing the old hook names (README, CLAUDE.md, install.sh,
  etc.)
- Update test files — remove tests for deleted functionality, update hook-name strings
- Run `zsh -n` and `bash -n` syntax checks on all changed scripts
- Run full bats suite; triage any new failures vs pre-existing
pitfalls:
- Settings JSONs exist in at least three locations (base config, ~/.claude/, ~/.snowflake/);
  missing any one leaves a stale hook registration that fires the wrong script at
  runtime
- Skills must be manually copied to the live directory — the base config change alone
  does not update the running environment
- Test files often contain the old hook name as a literal string in assertion text,
  not just in invocations — grep for both
- Prose-only doc files (architecture.md, cheatsheet.md, etc.) will still reference
  old names after the functional swap; they are non-blocking but create confusion
  for future readers
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.335077+00:00'
updated_at: '2026-06-11 22:41:19.335078+00:00'
---

# lifecycle-inversion-end-to-end-checklist

## description

Full checklist for inverting or renaming a hook pair that is registered in multiple places: shell files, settings JSONs, live env, docs, and tests.
