---
id: dotfiles-settings-floor-merge-workflow
project: borg-collective
domain: dotfiles
tags:
- dotfiles
- settings-management
- claude
- cortex
- zsh
- jq
- permissions
preconditions: []
steps:
- Locate the base settings file in the dotfiles repo (e.g., dotfiles/claude/settings.base.json)
- Substitute any __DOTFILES_DIR__ placeholders with the resolved dotfiles path before
  processing
- Read the machine-local settings file if it exists; treat as empty object {} if absent
- 'Use jq to union-merge: combine base permissions.allow array with local permissions.allow
  array, deduplicating'
- Write result via tmp file using the safe jq tmpfile pattern (never write directly
  to target)
- Generate ~/.config/borg/claude-settings.local.json template on first run if missing
  (for machine-local overrides)
- Repeat for each settings target (Claude, Cortex, etc.) — same shape, different paths
pitfalls:
- Placeholder substitution must happen before jq sees the file, not after; see decision
  20260415-dotfiles-placeholder-substitution-before-merge
- The merge must be additive-only; any logic that removes local entries will silently
  break machine-specific tool grants
- If the local settings file is malformed JSON, jq will fail silently or produce unexpected
  output — add a validation step before merging in future
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.989273+00:00'
updated_at: '2026-06-11 20:39:24.989273+00:00'
---

# dotfiles-settings-floor-merge-workflow

## description

Workflow for union-merging a versioned dotfiles settings base into machine-local settings files, used by borg setup for Claude and Cortex.
