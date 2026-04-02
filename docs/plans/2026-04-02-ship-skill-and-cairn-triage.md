# Project Plan: Ship Skill + Cairn Triage
*Established: 2026-04-02*
*Shipped: 2026-04-02 — PR #12 merged to main*

## Objective
Make `/borg-assimilate` execute shipping (not just evaluate), and triage cairn to decide whether to fix
or drop it.

## Acceptance Criteria

### borg-assimilate executes shipping
- [x] When all criteria met, borg-assimilate presents shipping commands and asks for confirmation
- [x] On confirmation: merges PR, marks plan checkboxes, archives PROJECT_PLAN.md to docs/plans/
- [x] Plan-specific ship definitions (beyond PR merge) are presented and executed with confirmation
- [x] After archival, PROJECT_PLAN.md is removed (no plan = no active work)
- [x] Verify: run /borg-assimilate on a test branch with all criteria met → confirm → PR merged, plan
  archived

### Cairn triage
*Split to separate plan — see PROJECT_PLAN.md*
- [ ] Diagnose why `cairn` is not in PATH (repo exists at ~/dev/cairn, postgres is running)
- [ ] Document: is cairn a pip install? A built binary? What's the install path?
- [ ] Either fix cairn installation so `cairn` CLI works, or document decision to drop it
- [ ] If fixed: verify `cairn search`, `cairn record`, and `cairn health` work end-to-end
- [ ] If dropped: remove cairn references from borg hooks/skills, simplify to debriefs-only

## Scope Boundaries
- borg-assimilate changes are to the skill only, not the CLI
- Cairn triage is diagnosis + decision, not a rewrite. If cairn needs significant work, that's a
  separate plan.

## Ship Definition
- Changes committed and PR merged to main
- All bats tests pass
- borg-assimilate manually tested with confirmation flow
- Cairn either works or is explicitly deferred with rationale documented

## Risks
- Cairn may require Python environment setup (venv, pip install) that isn't documented
- borg-assimilate executing `gh pr merge` needs the right permissions and branch protections

## Additional Work Shipped
- Fixed `borg scan` registry zeroing: Phase 2 jq failure could silently write 0-byte registry file.
  Added jq output validation and `_borg_registry_write()` empty-file guard.
- Fixed `--no-llm` flag being ignored: cairn-unavailable check no longer overrides explicit flag.
- Seeded `last_activity` from transcript file mtime in `borg scan` and `borg add`, so `borg hail`
  shows real timestamps instead of "(never)".
- Fixed zsh `local`-in-loop stdout leak: hoisted declarations to function scope.
