---
id: verb-80-20-extraction-sequence
project: borg-collective
domain: architecture
tags:
- mechanism-layer
- plugins
- refactor
- 80/20
- directives
preconditions: []
steps:
- 'Identify duplication: locate where the verb''s logic lives in borg.zsh and in any
  plugin skill files.'
- File a /borg-plan directive scoped to a single verb, parented to the umbrella plan
  (e.g., 2026-06-08-mechanism-layer-extraction-plugin-80-20-split).
- Extract shared logic to the mechanism layer (lib/ or equivalent), making the plugin
  self-contained.
- 'Prove the slice with the reaper pattern: single home + plugin calls in.'
- Open PR, squash-merge, delete branch.
- Archive the plan doc to docs/plans/assimilated/ with ship date and all criteria
  checked.
- Repeat for next verb (scan/scoring → cairn-client → search).
pitfalls:
- Scoring logic can exist in both borg.zsh and plugin files simultaneously; audit
  both before assuming extraction is complete.
- cairn calls are inconsistent between CLI and skills — treat cairn-client as its
  own verb extraction, not a side-effect of another verb's PR.
- Don't bundle multiple verbs into one PR; the reaper slice proved one-verb-at-a-time
  is the safe increment.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:03:01.143098+00:00'
updated_at: '2026-06-17 18:03:01.143104+00:00'
---

# verb-80-20-extraction-sequence

## description

Stepwise pattern for extracting a CLI verb into the mechanism layer so both CLI and skill plugins share a single implementation.
