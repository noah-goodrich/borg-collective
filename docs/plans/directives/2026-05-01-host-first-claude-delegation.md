# Directive: Host-First Claude with Container Delegation
*Established: 2026-05-01*

## Objective

Move per-project Claude sessions out of devcontainers and onto the host. Devcontainers become
build/test daemons that the host-side Claude dispatches to via `drone exec <project> -- <cmd>`.
Claude continues to launch inside each project's tmux window, but in a host pane with
`cwd=<project_dir>` instead of a `drone sh` → `claude` chain inside the container.

## Context

Running Claude inside devcontainers has been a recurring source of friction: per-container
`~/.claude` config sync via `postStartCommand` is fragile, container restarts kill the session,
and cross-project orchestration is painful when each session lives behind a separate
`docker exec`. Most Claude work is editing bind-mounted files plus running git — neither needs
the container env. Only env-dependent commands (`pytest`, `npm test`, language servers,
migrations) genuinely need the container.

The fix flips the default: Claude on host, container as a dispatch target. Per-project tmux
windows and the multi-pane layout stay; only the *contents* of the Claude pane change.

## Acceptance Criteria

- [ ] **`drone exec <project> -- <cmd>` primitive exists.** Thin wrapper around
      `docker compose exec -w <workspace_dir> <service> <cmd>` that resolves service name and
      workdir from the registry. Behaves like `drone sh` but takes a non-interactive command.
  - Verify: `drone exec cairn -- pytest -q` runs the cairn test suite from the host shell and
    returns its exit code unchanged.

- [ ] **Container-down state is fail-loud-and-self-heal.** When `drone exec` finds the container
      stopped, it prints a clear message ("container down — running drone up"), runs `drone up`,
      then retries the command exactly once. No silent auto-up.
  - Verify: `drone down cairn && drone exec cairn -- pytest -q` succeeds, prints the recovery
    message, and ends green.

- [ ] **`drone up` starts the Claude pane on host, not in container.** The pane spawns
      `cd <project_dir> && claude`, no `drone sh` prefix.
  - Verify: in the cairn drone window, the Claude pane's process tree shows `claude` as a child
    of the host shell, not of `docker exec`.

- [ ] **`drone claude <project>` reattaches via tmux send-keys.** No longer execs into the
      container. If the project's tmux window doesn't exist, behaves like `drone up`.
  - Verify: `drone claude cairn` from another window jumps to the cairn window and gives focus
    to the Claude pane.

- [ ] **Devcontainer `postStartCommand` cleanup.** `~/.claude` symlinks, `CLAUDE.md` copying,
      `.claude.json` injection are removed from devcontainer configs (they're dead code now).
      `dev-tools:bootstrap-project` skill updated to match.
  - Verify: `grep -rn "claude.json\|.claude/" templates/` returns no `postStartCommand` matches.

- [ ] **Per-project CLAUDE.md gains a "Running things" section.** Tells host-Claude the dispatch
      convention: env-dependent commands use `drone exec`, host-runnable commands run directly.
      Applies at minimum to cairn, ingle, reveal, snowfort.
  - Verify: each listed project's `CLAUDE.md` contains the section and at least one concrete
    `drone exec` example.

- [ ] **Global permission allow for `drone exec *`.** Avoids per-test prompt fatigue.
  - Verify: `~/.claude/settings.json` permissions include `drone exec *` under allow.

- [ ] **No hook double-fires.** `borg-link-down` and `borg-link-up` fire from host Claude only.
      Stale in-container claude installs (if any survive) do not fire duplicate registry writes.
  - Verify: trigger a `Stop` event from the host Claude pane in cairn; `~/.config/borg/registry.json`
      gets exactly one `last_activity` update.

## Scope Boundaries

- **NOT** removing `drone sh`. Still useful for ad-hoc human shells inside the container.
- **NOT** building command-classification heuristics (which commands need container vs host).
  Per-project `CLAUDE.md` handles it. Trade simplicity for explicitness.
- **NOT** changing the tmux pane layout. Multi-pane stays; only the Claude pane's spawn command
  changes.
- **NOT** auto-upping containers when nothing is dispatching to them. `drone exec`'s self-heal
  only triggers on actual command dispatch.
- **NOT** porting to Linux/Windows hosts. macOS-only matches the rest of borg.

## Ship Definition

- `drone.zsh` updated: new `cmd_exec`, modified `cmd_up` (host claude pane), modified
  `cmd_claude` (tmux send-keys reattach).
- Devcontainer templates cleaned of `~/.claude` syncing.
- CLAUDE.md updates landed in each affected project.
- Permission allowlist updated.
- Manual smoke test on at least two projects (one Python, one JS/TS) confirms host-Claude →
  `drone exec` → container test run end-to-end.
- Borg version bump and release.

## Timeline

Target: 1-2 focused sessions. The plumbing is small (`drone exec` is ~30 lines); the work is
the propagation across project CLAUDE.mds and devcontainer templates.

## Risks

1. **Hidden in-container Claude assumptions.** Some hooks or skills may implicitly assume Claude
   runs in the container (e.g., reading container-local paths). Audit `hooks/` and `skills/` for
   `/.dockerenv` checks and container-relative paths before flipping the default.

2. **Long-running processes.** Dev servers, watch mode, `tail -f` don't fit `drone exec`. They
   stay in their own tmux pane (typically already a separate pane in the drone layout). Confirm
   no project's workflow depends on running them from the Claude pane.

3. **fzf / interactive commands.** `drone exec` is non-interactive by default. If a workflow
   needs `-it` (e.g., interactive Python REPL for debugging), use `drone sh` instead. Document
   the split.

## Key Files

```
drone.zsh                                ← edit: cmd_exec (new), cmd_up, cmd_claude
templates/<all>/.devcontainer/devcontainer.json
                                          ← edit: strip postStartCommand claude config sync
skills/dev-tools/bootstrap-project/      ← edit: emit clean devcontainer scaffolding
~/.claude/settings.json                  ← edit: add `drone exec *` to permissions allow
hooks/borg-link-down.sh                  ← audit: confirm host-only assumptions
hooks/borg-link-up.sh                    ← audit: confirm host-only assumptions
<project>/CLAUDE.md (cairn, ingle, reveal, snowfort)
                                          ← edit: add "Running things" section
```
