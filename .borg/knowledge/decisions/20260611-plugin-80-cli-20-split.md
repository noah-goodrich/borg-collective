---
id: 20260611-plugin-80-cli-20-split
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- plugin
- cli
- mechanism-layer
- extraction-strategy
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.520222+00:00'
updated_at: '2026-06-11 22:41:19.520223+00:00'
---

# 20260611-plugin-80-cli-20-split

## decision

Adopt the plugin=80% / CLI=20% heuristic as the governing split for mechanism-layer extraction: shared logic lives in `lib/` and is sourced by plugins; CLI commands are thin wrappers.

## context

The reaper slice was the first full end-to-end proof of the extraction pattern; the session confirmed all 5 acceptance criteria with this split.

## reasoning

Plugins are the primary runtime; CLI commands are convenience wrappers. Pushing logic into `lib/` maximises reuse and testability (bats tests against lib functions directly).
