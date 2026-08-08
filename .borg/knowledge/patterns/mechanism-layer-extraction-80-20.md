---
id: mechanism-layer-extraction-80-20
project: borg-collective
domain: architecture
tags:
- refactoring
- shell
- plugin
- mechanism-layer
- posix
preconditions: []
steps:
- Identify the duplicated predicate/function across plugin (bash context) and CLI
  (zsh context)
- 'Audit all locations: lib files, hook files, and any prose descriptions in SKILL.md'
- Create `lib/<name>.sh` with POSIX-compatible syntax (no zsh-isms, no bashisms)
- Add the new lib file to bats test coverage before removing duplicates
- Update each consumer to `source lib/<name>.sh` and delete the inline duplicate body
- Replace SKILL.md inline prose with a pointer to the lib file
- Run shellcheck on all modified files; run full bats suite
- Run `scripts/sync-plugin.sh` to push updated SKILL.md to plugin distribution
pitfalls:
- zsh-specific syntax (e.g., `[[` with zsh extensions, `typeset -A`) in the extracted
  file will break bash consumers — test sourcing from both shells
- SKILL.md prose descriptions often lag the actual implementation; treat them as a
  third location to update, not documentation
- Plugin distribution (claude-plugins) is a separate repo — syncing it is a separate
  commit/push/PR step that is easy to forget
- 'The triple-mirror problem compounds silently: if you only update 2 of 3 locations,
  tests may still pass because tests hit the updated paths'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.503742+00:00'
updated_at: '2026-06-16 10:27:02.503743+00:00'
---

# mechanism-layer-extraction-80-20

## description

Extract a shared behavior that exists in multiple shell contexts (plugin/bash, CLI/zsh) into a single POSIX-compatible lib file, then update all consumers to source it. Proven on the reaper slice.
