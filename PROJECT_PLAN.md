# Project Plan: Fix Debrief Pipeline
*Established: 2026-04-08*

## Objective

Fix the debrief pipeline so that session debriefs reliably generate for all projects (host and
container), registry summaries stay current, and the orchestrator session gets useful context at
start.

## Acceptance Criteria

- [ ] `borg-stop.sh` debrief generation succeeds — `claude -p` auth works in the backgrounded
      subprocess; `.tmp` files get replaced by completed `.md` debriefs
  - Verify: `ls -la ~/.config/borg/debriefs/` shows `.md` files (not just `.tmp`) after session stop
- [ ] Container sessions map to registry projects — a session at `/development/packages/snowfort-audit`
      correctly resolves to the `snowfort` registry entry
  - Verify: stop a snowfort container session → `jq '.projects.snowfort.status' ~/.config/borg/registry.json`
    shows `"idle"` with updated `last_activity`
- [ ] Registry summaries update on stop — summary field populated from debrief objective
  - Verify: `jq '.projects.snowfort.summary' ~/.config/borg/registry.json` is not `null`
- [ ] Orchestrator session gets debrief context at start — `borg-start.sh` injects the last debrief
  - Verify: start a session in a project that has a debrief → see "Last session debrief" in context
- [ ] Host-only projects still work — borg-collective (no container) debriefs generate and load
  - Verify: stop and restart borg-collective session → debrief generates and appears in context
- [ ] End-to-end: `drone down snowfort` triggers debrief; next `drone up snowfort` session shows it
  - Verify: full drone down/up cycle

## Scope Boundaries

- NOT building: Cairn integration (optional, separate effort)
- NOT building: Changes to `borg hail` rendering (just fix the data pipeline)
- If done early: Ship, don't expand.

## Ship Definition

Committed to main + smoke test passes (drone down/up cycle for snowfort generates and loads debrief)

## Timeline

Target: this session
Estimated effort: 1 session, ~2 hours

## Risks

- `claude -p` auth may not work backgrounded — may need to switch to `curl` + Anthropic API
- Container hooks run inside the container — `claude` CLI auth, `$HOME`, paths all differ from host
- Transcript path in hook input may be container-local, complicating host-side generation
