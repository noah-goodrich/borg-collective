# Project Plan: Fix Debrief Pipeline
*Established: 2026-04-08*
*Shipped: 2026-04-08 — committed to main, smoke test passed*

## Objective

Fix the debrief pipeline so that session debriefs reliably generate for all projects (host and
container), registry summaries stay current, and the orchestrator session gets useful context at
start.

## Acceptance Criteria

- [x] `borg-stop.sh` debrief generation succeeds — `claude -p` auth works in the backgrounded
      subprocess; `.tmp` files get replaced by completed `.md` debriefs
  - Verify: `ls -la ~/.config/borg/debriefs/` shows `.md` files (not just `.tmp`) after session stop
- [x] Container sessions map to registry projects — a session at `/development/packages/snowfort-audit`
      correctly resolves to the `snowfort` registry entry
  - Verify: stop a snowfort container session → `jq '.projects.snowfort.status' ~/.config/borg/registry.json`
    shows `"idle"` with updated `last_activity`
- [x] Registry summaries update on stop — summary field populated from debrief objective
  - Verify: `jq '.projects.snowfort.summary' ~/.config/borg/registry.json` is not `null`
- [x] Orchestrator session gets debrief context at start — `borg-start.sh` injects the last debrief
  - Verify: start a session in a project that has a debrief → see "Last session debrief" in context
- [x] Host-only projects still work — borg-collective (no container) debriefs generate and load
  - Verify: stop and restart borg-collective session → debrief generates and appears in context
- [x] End-to-end: `drone down snowfort` triggers debrief; next `drone up snowfort` session shows it
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

## Additional Work Shipped

- Extracted shared `lib/borg-hooks.sh` with `_borg_find_project()` walk-up function
- Fixed `borg setup` to copy `lib/*.sh` to `~/.claude/lib/` alongside hooks
- `BORG_DEBRIEF_KEY` resolution: env → `ANTHROPIC_SDK_KEY` → macOS Keychain (avoids interfering
  with Max subscription `ANTHROPIC_API_KEY`)
- `drone.zsh`: single-pass `_read_devcontainer_exec_config()` replaces two separate jq calls;
  reads `workspaceFolder` and `remoteUser` from devcontainer.json
- `drone up` writes `.borg-project` marker in both local and devcontainer paths; `drone down` cleans it
- Snowfort project migrated from `~/dev/snowflake-projects/snowfort` to `~/dev/snowfort`;
  registry consolidated (removed `snowfort-audit` entry)
- `tests/test_helper/setup.bash`: copies `borg-hooks.sh` into bats sandbox home so hook tests pass
- Transcript tail changed from `tail -200` (990KB, caused claude to hang) to `tail -c 8000`
- Fixed debug redirect (`>/tmp/borg-debrief-debug.log` → `>/dev/null 2>&1`)
