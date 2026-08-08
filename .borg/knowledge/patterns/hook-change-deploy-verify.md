---
id: hook-change-deploy-verify
project: borg-collective
domain: infrastructure
tags:
- borg-collective
- hooks
- deployment
- borg-setup
- testing
preconditions: []
steps:
- Develop and test hook changes in the repo (tests/session_mode.bats or equivalent);
  run bats tests/ to confirm all cases green
- Merge branch to main (fast-forward preferred for clean history)
- Run 'borg setup' to copy updated hooks from repo into ~/.claude/hooks/
- Start a new Claude session to pick up the installed hooks (current session always
  uses hooks from when it started)
- 'Smoke test the target behavior: for orchestrator-mode, verify ~/dev renders overview
  block and ~/dev/borg-collective renders project checkpoint'
- Update any dependent directives or plans that were blocked on the change being live
pitfalls:
- 'Forgetting borg setup: the most common failure mode — code is on main but behavior
  is unchanged because installed hooks weren''t updated'
- 'Testing in the current session: the session that did the merge still runs old hooks;
  always verify in a fresh session'
- 'Self-referential path trap: if developing borg-collective itself, cwd is a subdirectory
  of BORG_ORCHESTRATOR_ROOT — confirm exact-match logic handles this correctly in
  smoke test'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.428511+00:00'
updated_at: '2026-06-11 22:41:19.428511+00:00'
---

# hook-change-deploy-verify

## description

Safe workflow for shipping borg hook changes from development through to active use, accounting for the two-layer install model (repo vs installed hooks).
