---
id: plugin-self-containment-80-20-split
project: borg-collective
domain: architecture
tags:
- plugins
- mechanism-layer
- reaper
- 80-20
- self-containment
preconditions: []
steps:
- Identify verbs where ≥80% of call volume comes from a single entry point (e.g.,
  `reap` called almost exclusively from `borg reap`).
- Extract the shared logic to a mechanism-layer module (e.g., lib/reaper.zsh) that
  both CLI and skill paths source.
- 'Ensure the plugin directory remains self-contained: all files needed for a fresh
  install live inside the plugin dir or are fetched at install time.'
- Wire the mechanism module as a single source-of-truth; remove duplicated logic from
  borg.zsh and any skill files.
- Validate with a fresh-install smoke test before merging.
pitfalls:
- Functions inlined inside hooks (e.g., _borg_osa_notify in hooks/notify.sh) for fresh-install
  safety are easy to miss when auditing—check hooks separately from lib/.
- If the mechanism module is sourced by the CLI but not by the skill runner, you'll
  have silent divergence; audit both source paths.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.513390+00:00'
updated_at: '2026-06-16 10:27:02.513390+00:00'
---

# plugin-self-containment-80-20-split

## description

Extract high-frequency plugin verbs to a mechanism layer (single reaper home) while keeping the plugin self-contained for install/portability. Proven pattern via PR #41.
