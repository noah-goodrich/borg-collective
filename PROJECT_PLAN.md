# Project Plan: Ship Skill + Cairn Triage
*Established: 2026-04-02*

## Objective
Make `/borg-ship` execute shipping (not just evaluate), and triage cairn to decide whether to fix
or drop it.

## Acceptance Criteria

### borg-ship executes shipping
- [ ] When all criteria met, borg-ship presents shipping commands and asks for confirmation
- [ ] On confirmation: merges PR, marks plan checkboxes, archives PROJECT_PLAN.md to docs/plans/
- [ ] Plan-specific ship definitions (beyond PR merge) are presented and executed with confirmation
- [ ] After archival, PROJECT_PLAN.md is removed (no plan = no active work)
- [ ] Verify: run /borg-ship on a test branch with all criteria met → confirm → PR merged, plan
  archived

### Cairn triage
- [ ] Diagnose why `cairn` is not in PATH (repo exists at ~/dev/cairn, postgres is running)
- [ ] Document: is cairn a pip install? A built binary? What's the install path?
- [ ] Either fix cairn installation so `cairn` CLI works, or document decision to drop it
- [ ] If fixed: verify `cairn search`, `cairn record`, and `cairn health` work end-to-end
- [ ] If dropped: remove cairn references from borg hooks/skills, simplify to debriefs-only

## Scope Boundaries
- borg-ship changes are to the skill only, not the CLI
- Cairn triage is diagnosis + decision, not a rewrite. If cairn needs significant work, that's a
  separate plan.

## Ship Definition
- Changes committed and PR merged to main
- All bats tests pass
- borg-ship manually tested with confirmation flow
- Cairn either works or is explicitly deferred with rationale documented

## Risks
- Cairn may require Python environment setup (venv, pip install) that isn't documented
- borg-ship executing `gh pr merge` needs the right permissions and branch protections
