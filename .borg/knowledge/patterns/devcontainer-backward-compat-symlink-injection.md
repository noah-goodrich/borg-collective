---
id: devcontainer-backward-compat-symlink-injection
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- scaffold
- template
- symlink
- postStartCommand
preconditions: []
steps:
- Define a `__WS_SYMLINK__` placeholder in the devcontainer template's `postStartCommand`
- 'In `_subst_template`, resolve `__WS_SYMLINK__`: if workspace == `/workspace`, expand
  to empty string; otherwise expand to `sudo rm -rf /workspace && sudo ln -sfn <workspace>
  /workspace`'
- Set workspace default to `/workspaces/<project_name>` (after preset check, so explicit
  flags win)
- Store an `workspace_explicit` flag so user-supplied `--workspace` values bypass
  the default logic
pitfalls:
- The symlink command uses `sudo rm -rf /workspace` — if workspace resolution is wrong,
  this can silently destroy an existing directory at container start
- Template substitution must happen after all variable resolution (preset + explicit
  flag + default); ordering bugs will produce literal `__WS_SYMLINK__` strings in
  the generated devcontainer.json
- '`postStartCommand` runs in the container, not the host — symlink is ephemeral if
  the container is rebuilt without a persistent volume at `/workspace`'
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.321282+00:00'
updated_at: '2026-06-11 22:41:19.321282+00:00'
---

# devcontainer-backward-compat-symlink-injection

## description

Inject a conditional symlink creation into devcontainer `postStartCommand` via a template placeholder so legacy `/workspace` paths remain valid when the real workspace is at a non-standard path.
