---
id: borg-hook-deploy-topology
project: borg-collective
domain: infrastructure
tags:
- borg
- hooks
- deployment
- claude
- zsh
preconditions: []
steps:
- Identify whether the changed file is a hook (borg-hooks.sh, borg-link-down.sh, etc.)
  or a lib/*.zsh file
- 'For hook files: cp <repo>/hooks/<file> ~/.claude/<file>'
- 'For lib/*.zsh: no copy needed — CLI sources from repo directly'
- Run borg setup to validate hook registration (no-op if hooks already synced)
- Smoke-test the affected command (borg next, borg reap, etc.)
pitfalls:
- Editing a hook in the repo without copying to ~/.claude means the live Claude session
  runs the old version silently — always copy after hook edits
- borg-link-down.sh capacity scan must stay in sync with the CLI reaper logic; they
  are separately maintained
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.512363+00:00'
updated_at: '2026-06-11 22:41:19.512364+00:00'
---

# borg-hook-deploy-topology

## description

Deploy borg hook files to ~/.claude (copied, not symlinked) while CLI lib/*.zsh files run from source repo. After any hook change, manually copy to ~/.claude; after any lib/*.zsh change, no copy needed.
