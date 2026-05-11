# Directive: Orchestrator-Mode Session Separation

*Filed: 2026-05-11*
*Predecessor to: `2026-05-XX-per-project-state-migration.md` (Directive B,
stub filed alongside).*

## Objective

Distinguish orchestrator-mode sessions (launched from `$BORG_ORCHESTRATOR_ROOT`,
default `$HOME/dev`) from project-mode sessions in all three hook scripts.
Orchestrator-mode `SessionStart` renders a scannable cross-project overview
instead of injecting a single project's checkpoint, and the orchestrator session
writes nothing to `~/.config/borg/registry.json`. Project-mode sessions behave
exactly as they do today.

## Context

Today every hook treats every session as a project session. `_borg_find_project`
in `lib/borg-hooks.sh:21` walks up from `$CWD` for a `.borg-project` marker; if
none is found (the host orchestrator case), it falls back to `basename "$CWD"`
and the hook writes registry status for whatever that basename happens to be.

Consequences:
- Launching Claude from `~/dev` writes `status=active` to a registry key named
  `dev` (or invents one if absent).
- Launching from `~/dev/borg-collective` flips the `borg-collective` registry
  entry to active even when the session is really doing cross-project
  orchestration (listing projects, deciding priorities, dispatching agents).
- `SessionStart` injects whichever single project's checkpoint matches the cwd
  basename, which is never what an orchestrator session actually wants.

The fix is one explicit mode check at the top of each hook plus a different
code path for orchestrator mode in `SessionStart`.

## Variable Vocabulary (introduced by this directive)

- **`BORG_ORCHESTRATOR_ROOT`** (default `$HOME/dev`): the workspace root where
  the orchestrator session runs. A session whose `$CWD` exactly matches this
  path is in orchestrator mode. Replaces the current overloaded use of
  `BORG_ROOT` for this purpose.
- **`BORG_ROOT`** (repurposed): the install path of the borg-collective source
  tree itself (today `$HOME/dev/borg-collective`). Exposed by `install.sh` so
  tools that need to find the source tree (hooks resolving skill paths, setup
  re-runs) don't have to derive it from `${0:A:h}` each time. Internal
  `BORG_HOME` in `install.sh:24` becomes an alias for one release, then is
  removed.

Renames required (8 known sites):
- `borg.zsh:23` — `BORG_ROOT` → `BORG_ORCHESTRATOR_ROOT` (workspace-root semantics).
- `drone.zsh:36, 120-122, 1203, 1212` — same rename.
- `lib/registry.zsh:122` — same rename (the `borg_scan_path_should_skip` check).
- `README.md:234`, `docs/architecture.md:164`, `docs/cheatsheet.md:105` —
  documentation updates.
- `docs/plans/reviews/2026-05-07-nanoprobe-verification.md:21` — historical
  doc; leave as-is or add a note that the var was renamed.

## Acceptance Criteria

- [ ] **`_borg_session_mode` exists in `lib/borg-hooks.sh`** and returns
      `orchestrator` when `$CWD` equals `$BORG_ORCHESTRATOR_ROOT` (with a
      sensible default `$HOME/dev`), `project` otherwise. Exact match only,
      no descendant matching.
  - Verify: new bats test in `tests/borg.bats` asserts both outcomes plus the
    edge cases — trailing slash, symlinked `$HOME/dev`, `$BORG_ORCHESTRATOR_ROOT`
    unset (fallback to default), and `$CWD` being a project root *inside*
    `$BORG_ORCHESTRATOR_ROOT` (must still be `project`).
- [ ] **`SessionStart` in orchestrator mode** renders the cross-project overview
      block and writes NOTHING to `~/.config/borg/registry.json`.
  - Verify: launch Claude from `$HOME/dev` (or `$BORG_ORCHESTRATOR_ROOT` if
    overridden), confirm `additionalContext` contains the overview, confirm
    `stat -f %m ~/.config/borg/registry.json` is unchanged across the launch.
- [ ] **`SessionStart` in project mode** behaves identically to today:
      `status=active`, latest checkpoint injected, active directives listed,
      cairn knowledge surfaced.
  - Verify: launch Claude from `~/dev/reveal` (or any project), confirm
    `additionalContext` includes the checkpoint header and registry shows
    `status=active`.
- [ ] **`Stop` and `Notification` hooks in orchestrator mode** write NOTHING to
      registry. No spurious `status=idle` or `status=waiting` flips on any
      project key when the orchestrator session ends or pauses for input.
  - Verify: stop an orchestrator session, capture
    `jq '.projects' ~/.config/borg/registry.json` before and after, diff is
    empty modulo timestamps.
- [ ] **`BORG_ORCHESTRATOR_ROOT` is the single name** for workspace-root
      semantics; `BORG_ROOT` is reserved for install-path semantics going
      forward.
  - Verify: `grep -rn "BORG_ROOT" .` shows only install-path usage (or no
    usage if delayed); `grep -rn "BORG_ORCHESTRATOR_ROOT" .` shows usage in
    `lib/borg-hooks.sh`, `lib/registry.zsh`, `borg.zsh`, `drone.zsh`, and the
    three hook scripts.
- [ ] **Cortex Code (CoCo) sessions behave the same way.** Both hook
      registrations in `borg.zsh cmd_setup` (Claude + CoCo blocks) consult
      `_borg_session_mode` consistently.
  - Verify: launch CoCo from `$BORG_ORCHESTRATOR_ROOT`, confirm overview
    renders and no registry write occurs.
- [ ] **No regression in `borg ls` / `borg next` output.** Registry consumers
      in `borg.zsh` are unchanged this directive (state still lives in
      registry; Directive B moves it).
  - Verify: snapshot `borg ls` output before/after, diff is empty modulo
    timestamps in the `last_activity` column.

## Scope Boundaries

- **NOT moving any field out of `~/.config/borg/registry.json`.** All current
  fields (`status`, `last_activity`, `claude_session_id`,
  `has_uncommitted_changes`, `waiting_reason`, `notify_origin`) stay where
  they are. Directive B handles that migration.
- **NOT writing any `<project>/.borg/state.json` files.** New artifact lands in
  Directive B.
- **NOT changing `borg ls` / `borg next` / `borg switch` consumers in
  `borg.zsh`.** Same data source as today.
- **NOT refactoring `_borg_find_project` itself.** It keeps its current
  signature and fallback behavior — only the new `_borg_session_mode` is added
  alongside.
- **NOT building a shared renderer** between this hook and the `/borg-link`
  skill. Inline a minimal overview implementation in `borg-link-down.sh`. If
  duplication itches, that's Directive B's problem (or a separate refactor).
- **If done early:** file Directive B's stub (already drafted) and stop. Do
  not sneak the registry shrink into this directive.

## Ship Definition

- Committed to `main`.
- `bats tests/borg.bats` green (existing tests plus the new mode-check
  coverage).
- `borg setup` re-runs clean on a fresh `~/.claude/` (smoke).
- Manual smoke: launch orchestrator from `$HOME/dev` → see overview, no
  registry write. Launch project from `~/dev/reveal` → see checkpoint header,
  see `status=active` in registry.
- Updated `CLAUDE.md` notes the `BORG_ORCHESTRATOR_ROOT` vs `BORG_ROOT`
  distinction in the "Patterns" section.
- No `BORG_VERSION` bump required (no on-disk schema change). Bump arrives
  with Directive B.

## Timeline

Target: one session, ~1.5 hours.

Estimated effort breakdown:
- Add `_borg_session_mode` to `lib/borg-hooks.sh` + bats coverage: 20 min.
- Mode-guard the three hook scripts: 20 min.
- Implement orchestrator-mode overview rendering in `borg-link-down.sh`: 30 min.
- `BORG_ROOT` → `BORG_ORCHESTRATOR_ROOT` rename across the 8 known sites: 15 min.
- Manual smoke (both modes, Claude + CoCo): 15 min.
- Doc updates (README, CLAUDE.md, architecture.md, cheatsheet.md): 10 min.

## Risks

- **Exact-match cwd check** for orchestrator mode means a user who happens to
  `cd ~/dev` for non-orchestrator reasons (a quick `ls`, a stray Claude
  session) gets orchestrator mode. Side effect is benign — render overview,
  no destructive write — so accepting the risk.
- **CoCo hook registration** is registered twice (Claude + CoCo block in
  `cmd_setup`); easy to update one and forget the other. Acceptance criterion
  forces verification of both.
- **Overview-rendering bloat** in `borg-link-down.sh` (already 238 lines). A
  minimal renderer is ~30 lines (jq over registry, find newest checkpoint per
  project, glob directives). If it grows past ~80 lines, extract to a helper
  in `lib/borg-hooks.sh` — but the temptation to share with `/borg-link` is a
  scope trap. Resist.
- **Documentation drift** if the rename misses a site. The `grep -rn` checks
  in acceptance criteria are the safety net.

## Key Files

- `lib/borg-hooks.sh` — add `_borg_session_mode`.
- `hooks/borg-link-down.sh` — orchestrator-mode branch + overview renderer.
- `hooks/borg-link-up.sh` — orchestrator-mode early-exit.
- `hooks/borg-notify.sh` — orchestrator-mode early-exit.
- `borg.zsh:23` — `BORG_ROOT` → `BORG_ORCHESTRATOR_ROOT`.
- `drone.zsh:36, 120-122, 1203, 1212` — same rename.
- `lib/registry.zsh:122` — same rename.
- `install.sh` — expose `BORG_ROOT` as install path (new), document
  `BORG_ORCHESTRATOR_ROOT` in the summary output.
- `tests/borg.bats` — new mode-check coverage.
- `README.md`, `CLAUDE.md`, `docs/architecture.md`, `docs/cheatsheet.md` —
  documentation updates.
