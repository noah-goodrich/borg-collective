---
id: 20260527-gitignore-state-json-not-borg-dir
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- gitignore
- state-management
- setup
- checkpoints
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.492899+00:00'
updated_at: '2026-06-11 22:41:19.492899+00:00'
---

# 20260527-gitignore-state-json-not-borg-dir

## decision

In cmd_setup, add .borg/state.json to .gitignore rather than .borg/ (the whole directory).

## context

The setup command previously added .borg/ to gitignore, which inadvertently excluded .borg/checkpoints/ — a directory users may want tracked. This was a pre-existing bug surfaced during the Directive B migration.

## reasoning

Only state.json is volatile/machine-specific and should be ignored. Checkpoint files under .borg/checkpoints/ are intentionally versioned artifacts. Ignoring the parent directory breaks the !.borg/checkpoints/ negation pattern.
