---
id: drone-workspace-symlink-backcompat
project: borg-collective
domain: infrastructure
tags:
- drone
- devcontainer
- scaffold
- workspace
- symlink
- postStartCommand
preconditions: []
steps:
- Add a `__WS_SYMLINK__` placeholder to `devcontainer.json`'s `postStartCommand` in
  the template.
- In `_subst_template`, expand `__WS_SYMLINK__` to `sudo rm -rf /workspace && sudo
  ln -sfn <new_workspace> /workspace` when the workspace is not `/workspace`; expand
  to empty string otherwise.
- In `cmd_scaffold`, set workspace default to `/workspaces/<project_name>` after preset
  check; set `workspace_explicit` flag when user passes `--workspace` explicitly.
- Verify the generated `devcontainer.json` has the correct `postStartCommand` before
  `docker compose up`.
pitfalls:
- The symlink command uses `sudo rm -rf /workspace` before re-creating it — ensure
  `/workspace` is never a real data directory in any legacy container before applying
  this pattern.
- If `__WS_SYMLINK__` substitution is skipped (e.g., workspace IS `/workspace`), the
  placeholder must expand to a no-op, not be left as a literal string.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.124788+00:00'
updated_at: '2026-06-11 20:39:25.124788+00:00'
---

# drone-workspace-symlink-backcompat

## description

When changing a devcontainer's default workspace path, inject a backward-compat symlink via `postStartCommand` so existing tooling that hardcodes the old path continues to work.
