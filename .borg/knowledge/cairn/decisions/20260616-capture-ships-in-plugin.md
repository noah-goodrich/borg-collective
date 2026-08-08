---
id: 20260616-capture-ships-in-plugin
date: '2026-06-16'
project: cairn
domain: architecture
tags:
- cairn
- borg-collective
- mcp
- plugin
- cli
- capture
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.260965+00:00'
updated_at: '2026-06-16 10:27:03.260967+00:00'
---

# 20260616-capture-ships-in-plugin

## decision

Cairn knowledge capture ships in the borg-collective plugin (curl to /mcp/ from Stop hook), not in the cairn CLI repo

## context

Deciding where to put the session-end capture logic — it could live in the cairn custom CLI or in the borg plugin hooks

## reasoning

The plugin already owns the Stop hook lifecycle; adding capture there keeps cairn's CLI repo as a pure server. Any code added to the custom CLI repo only creates coupling that gets lost when the CLI is replaced. Verified cli_coupling_leak=false via adversarial workflow.
