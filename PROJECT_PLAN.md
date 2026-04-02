# Project Plan: Orchestrator-First Borg
*Established: 2026-04-01*

## Objective
Make the borg orchestrator session self-contained by exposing navigation/dashboard/search commands as
skills, fix silent cairn failures with health checks and warnings, default to LLM summaries when cairn
is empty, streamline existing skills for lower token overhead, and add automated tests for the full
context lifecycle.

## Acceptance Criteria
- [ ] Orchestrator skills exist for: next, ls, switch, brief, search, refresh, status
  - Verify: Each `/borg-*` skill is invocable from inside a Claude session and produces correct output
  - Verify: `borg setup` registers all new skills
- [ ] `borg refresh` defaults to LLM summaries when cairn has no data for a project
  - Verify: `borg refresh project-name` without `--llm` generates LLM summary when cairn returns empty
- [ ] Cairn health check at session start warns visibly when cairn is unreachable or has no data
  - Verify: Stop cairn → start session → see clear warning in session context
- [ ] Cairn write failures are surfaced, not silently swallowed
  - Verify: Stop cairn → stop session → see warning that debrief was NOT committed to cairn
- [ ] Existing skills reviewed and streamlined for token efficiency
  - Verify: Total skill SKILL.md bytes reduced or held steady despite adding 7 new skills
  - Verify: No functional regressions in existing skills
- [ ] Automated bats tests cover context lifecycle: start hook → context injection → stop hook →
  debrief → cairn commit → next session reads debrief
  - Verify: `bats tests/lifecycle.bats` passes
- [ ] Automated bats tests cover cairn integration: health check, search, record, failure modes
  - Verify: `bats tests/cairn.bats` passes
- [ ] All pre-existing tests still pass
  - Verify: `bats tests/` — all green

## Scope Boundaries
- Skills layer ON TOP of CLI commands, not replacing them. Whether CLI commands should eventually be
  deprecated in favor of skills-only is a design question for a future session.
- If done early: ship what we have, don't expand scope.

## Ship Definition
- Changes committed to `borg-v3-workflow-automation` branch
- All bats tests pass (new + existing)
- Skills manually smoke-tested in orchestrator session
- PR opened against main

## Timeline
Target: 2-3 sessions (~2 hours each)
- Session 1: Cairn health checks + `refresh --llm` default + cairn bats tests
- Session 2: Orchestrator skills (7 skill wrappers) + skill streamlining
- Session 3: Lifecycle integration tests + regression sweep + PR

## Risks
- Cairn may be fundamentally broken, not just missing health checks. Need to diagnose actual failure
  mode before assuming the fix is just "add warnings."
- Skills sourcing borg library functions — zsh sourcing in a Claude Bash tool context may behave
  differently than interactive shell. Need to test the execution path.
- Hook testing requires mocking Claude Code's hook input JSON format, which isn't formally documented.
  Will need to reverse-engineer from existing hooks.
