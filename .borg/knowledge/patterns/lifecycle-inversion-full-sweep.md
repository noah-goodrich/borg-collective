---
id: lifecycle-inversion-full-sweep
project: borg-collective
domain: infrastructure
tags:
- refactoring
- lifecycle
- hooks
- naming
- sweep
preconditions: []
steps:
- 1. File renames first via `.swap` intermediate to avoid clobber
- '2. Content swap: update header comments, internal references, SKILL.md name/description/heading'
- 3. Update registration code (cmd_setup or equivalent) — every place both names appear
  (often 4+ registration blocks for multi-AI support e.g. Claude + CoCo)
- 4. Update canonical config files (e.g. settings.base.json)
- '5. Update live environment: installed hooks, settings JSONs in all active tool
  dirs, installed skill dirs — verify each with `jq` or equivalent'
- '6. Docs sweep: README, CLAUDE.md, install.sh help text, any tool-count or nudge
  text files, other skills'' SKILL.md that cross-reference'
- '7. Test sweep: update all bats/test files referencing old hook/skill names in assertions
  and test descriptions'
- '8. Memory/index sweep: update any MEMORY.md index entries and memory files that
  record the old names'
- '9. Syntax check all modified files: `zsh -n`, `bash -n`, `jq empty` as appropriate'
- 10. Run full test suite; triage failures — distinguish pre-existing from newly introduced
- 11. Run /simplify before committing
- '12. Commit as two logical commits: one for the core change, one for simplification'
pitfalls:
- Registration code often has multiple blocks for the same hook (e.g. one for Claude,
  one for CoCo) — missing any one leaves a stale reference that causes subtle runtime
  bugs
- Live environment (installed hooks, active settings JSONs) is separate from repo
  files — must update both or the running system diverges from source
- Prose-only docs (architecture.md, six-pager.md, etc.) are easy to miss and leave
  confusing stale references even though they don't affect functionality
- Test descriptions (not just assertions) may embed old names — grep for both
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.160024+00:00'
updated_at: '2026-06-11 20:39:25.160024+00:00'
---

# lifecycle-inversion-full-sweep

## description

Complete sweep pattern for inverting hook/skill naming semantics across an entire codebase — hits all layers so nothing is left with stale names
