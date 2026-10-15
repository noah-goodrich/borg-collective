# Rules for editing borg.zsh, drone.zsh and the CLI

Rules moved verbatim from the top-level CLAUDE.md. They guard root files, which cannot hold a nested CLAUDE.md.

- **CLI structure mirrors dev.sh**: `set -e`, case dispatch, colored output, `cmd_*` naming
- **Registry writes are atomic**: write to tmp file, `mv` to final path
- **Vocabulary: `repository` is the code word for a git repo; `project` means a cross-repo workstream (rename decided 2026-10-12)**: the code used `project` for both, and the rename (`docs/plans/directives/2026-08-31-project-to-repository-rename.md`, site inventory under `docs/plans/directives/assets/`) moves the repository sense to `repository` in five PRs by area (R1 `borg_core/link`, R2 the rest of `borg_core`, R3 `lib/` and `hooks/`, R4 `borg.zsh`, R5 `drone.zsh` plus `merge-tree/`, `evals/`, `templates/` and `install.sh`), with tests and goldens moving in the step whose output they pin. User-facing words change too (help text, messages, placeholders, column headers say "repository" where they mean one); command and flag names never change. Workstream-sense rows (a manifest or chain describes a project) are never renamed. **Kept permanently as contract names: the `.borg-project` marker filename, every `borg link --json` key (`projects`, `total_projects`, the `project` field on directive, assimilated and cortex_pending records) and `BORG_PROJECT_NAME`.** Why: they are on-disk and cross-repo wire names, so renaming them buys nothing a reader sees and breaks consumers outside this repo, including the distributed plugin (the `borg-link` skill's MARKER-WALK block reads the marker and its `--json` reader reads the keys). A Python variable or keyword argument may be renamed while the key string it reads stays, which is why `assemble(projects=...)` still mirrors the document. The registry key `projects` migrates LAST, in its own PRs: a reader that accepts both `projects` and `repositories`, then the file migration, then dropping the old key (expand, migrate, contract). Expand has shipped: every reader accepts either key (Python through `borg_core.paths.normalize_registry`, shell and hooks through `BORG_REGISTRY_NORM_JQ` and `borg_registry_normalized` in `lib/reaper.sh`), every writer still writes `projects`, and `python3 -m borg_core.registry.cli migrate-key [--dry-run]` renames the key in a registry file (timestamped backup first, a no-op when it already has `repositories`); it has not been run against any real registry.
- **Skills do the thinking**: Claude proposes, developer validates. Minimum cognitive load.
- **Debriefs replace summaries**: LLM analysis at session stop, not regex extraction
- **Boundaries are speed bumps**: one-keystroke confirmations, not hard blocks
- **Window names**: the registry's `tmux_window` is the ONE window-name value; drone creates the window with
  it and borg looks it up by it. Valid means non-empty, no `.` or `:` (tmux target syntax), not the tmux
  session name, and not another repository's name or `tmux_window` (`validate_window_name`). Derivation
  (`derive_window_name`, run by `drone up` when `needs_derivation` says the field was never customized) is
  deterministic: names up to 6 chars stay, 3+ segments on `-`/`_` become initials, otherwise the first 6 chars,
  lengthening on collision. `borg-collective` therefore becomes `borg-c`, because `borg` is the session name
  and may not be a window. `borg window <repository> [short]` reads or sets it; an explicit name survives
  re-derivation and survives `borg add`. **Lookups accept either form**: a live window under the registry
  name OR the repository name is the repository's window, so windows opened before short names existed keep
  working. That rule has three statements: `_drone_find_window` (drone.zsh), `borg_tmux_find_window`
  (lib/tmux.zsh, used by `borg switch`, `borg next --switch` and `borg color`) with the reap overlay in
  lib/registry.zsh, and `window_is_live` (borg_core/link/core.py). Change one, change all three.
- **borg-hooks (host-side lifecycle)**: repositories can ship executable `.devcontainer/borg-hooks/pre-up.sh`
  and `.devcontainer/borg-hooks/post-down.sh` scripts. `pre-up.sh` runs on the host before
  `docker compose up -d` (strict: non-zero aborts `drone up`); `post-down.sh` runs after
  `docker compose down` in `drone down` only (lenient: non-zero warns, drone exits 0). Hooks
  run with `cwd=$repository_dir` and `BORG_PROJECT_NAME` exported. Transient downs during
  `drone restart`/`rebuild` do NOT fire `post-down.sh` — external stacks (e.g. Supabase)
  must persist across cycles. New Supabase-backed repositories scaffold via `drone scaffold --supabase <dir>`.
- **`drone scaffold --supabase <dir>`**: generate a devcontainer joined to the external
  `supabase_network_<repository>` network plus standard borg-hooks that call `supabase start`
  on up and `supabase stop` on down.
- **`drone scaffold --supabase-shared <dir>` (opt-in, INERT until cutover)**: a second,
  separate scaffold path for the shared-local-Supabase consolidation. Instead of a
  per-repository Supabase instance, the generated devcontainer joins the fixed, always-on
  `supabase_network_stillpoint` Docker network (containers `supabase_*_stillpoint`, ports
  API 54321 / DB 54322 / Analytics 54327). Shared config lives in the `stillpoint` repo
  (`~/dev/stillpoint/supabase`, overridable via `BORG_STILLPOINT_SUPABASE_DIR`). Templates
  at `templates/supabase-shared/`. The shared stack is **ALWAYS-ON** — started once, never
  per-drone: `borg-hooks/pre-up.sh` checks `docker inspect -f '{{.State.Running}}'
  supabase_db_stillpoint` and only runs `supabase start` (from the stillpoint repo) if it
  isn't already running; it never runs a per-repository `supabase init`/`start`.
  `borg-hooks/post-down.sh` is a hard no-op — an individual `drone down` must never stop
  infra shared by other repositories. Stop the shared stack explicitly and deliberately from
  the stillpoint repo (`supabase stop`), never via a drone's lifecycle. Does not alter
  `--supabase` semantics; the two scaffold paths are independent. This mechanism is scaffolded
  but not yet wired into any repository — no per-repository cutover has happened.
