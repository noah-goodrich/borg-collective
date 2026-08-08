---
id: jq-additive-union-merge-settings
project: borg-collective
domain: infrastructure
tags:
- jq
- settings-management
- idempotency
- dotfiles
- zsh
preconditions: []
steps:
- Read the versioned base file; substitute any path placeholders (e.g. __DOTFILES_DIR__)
  via sed before JSON parsing
- Use jq with --slurpfile or process substitution to load both the live file and the
  substituted base
- 'Compute the union: ($live.permissions.allow + $base.permissions.allow | unique)
  and write back with |= update syntax'
- Guard machine-local fields in a separate overlay template file; generate the template
  with 'if [[ ! -f ]]' to avoid overwriting
- Run the merge step idempotently — repeated runs should produce identical output
  given the same inputs
pitfalls:
- If sed substitution is skipped, jq receives a literal placeholder string in a path
  value, which silently produces wrong config rather than an error
- Using = (overwrite) instead of |= (update) on the parent object will drop all other
  keys in the settings file
- The once-and-never-overwrite guard must be on the local overlay template, not the
  merged output, or machine customizations will be lost
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.978616+00:00'
updated_at: '2026-06-11 20:39:24.978616+00:00'
---

# jq-additive-union-merge-settings

## description

Idempotently merge a versioned JSON array (e.g. permissions.allow) from a dotfiles base into a live settings file using jq, preserving all existing live entries
