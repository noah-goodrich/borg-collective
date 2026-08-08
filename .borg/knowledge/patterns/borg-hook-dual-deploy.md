---
id: borg-hook-dual-deploy
project: borg-collective
domain: infrastructure
tags:
- borg
- hooks
- deployment
- zsh
- bash
preconditions: []
steps:
- Implement the feature function in lib/registry.zsh for CLI availability
- Copy/duplicate the function into lib/borg-hooks.sh for hook context
- 'Deploy hook files: cp lib/borg-hooks.sh ~/.claude/ (and any companion hook scripts)'
- Verify CLI path works via direct borg <command> invocation
- Verify hook path fires correctly via link-down simulation
pitfalls:
- Forgetting to deploy to ~/.claude means hooks run stale code even though CLI runs
  from source
- Divergence between the two definitions accumulates silently over time — document
  the duplication explicitly
- borg setup may appear to be a no-op after manual deploy; confirm what setup actually
  syncs before relying on it
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.492704+00:00'
updated_at: '2026-06-16 10:27:02.492705+00:00'
---

# borg-hook-dual-deploy

## description

When a borg feature must work in both CLI and hook execution contexts, define it in both lib/registry.zsh and lib/borg-hooks.sh, then deploy hook files to ~/.claude
