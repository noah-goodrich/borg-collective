---
id: jq-safe-inplace-json-merge
project: borg-collective
domain: shell-scripting
tags:
- jq
- json
- shell
- dotfiles
- atomic-write
- error-handling
preconditions: []
steps:
- 'Write merged result to a tmp file: jq ''...'' source.json target.json > "$tmp"'
- 'On jq failure, remove tmp and return early: || { rm -f "$tmp"; return 1; }'
- 'On success, move tmp over target atomically: mv "$tmp" target.json'
- Never write directly to the target — jq reads and writes simultaneously on the same
  file path produce empty output
pitfalls:
- If you skip the tmp file and pipe jq output directly back to the target (e.g. via
  sponge or redirection), jq may read an empty file because the shell truncates the
  target before jq opens it
- Forgetting to rm the tmp file on jq failure leaves a corrupt or empty JSON fragment
  at the tmp path, which may be picked up by a subsequent run
- mv is not atomic across filesystems — ensure tmp and target are on the same filesystem
  (both in $HOME is safe)
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.006419+00:00'
updated_at: '2026-06-11 20:39:25.006419+00:00'
---

# jq-safe-inplace-json-merge

## description

Safely merge two JSON files in-place using jq with a tmp file, cleaning up on failure to avoid leaving corrupt state
