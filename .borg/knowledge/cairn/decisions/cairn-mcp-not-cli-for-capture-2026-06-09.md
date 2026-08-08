---
id: cairn-mcp-not-cli-for-capture-2026-06-09
date: '2026-06-10'
project: cairn
domain: architecture
tags:
- mcp
- architecture
- borg
- capture
alternatives: []
applies_to: []
confidence: 0.92
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260610-1630-cairn
created_at: '2026-06-10 16:50:37.414863+00:00'
updated_at: '2026-06-10 16:50:37.414863+00:00'
---

# cairn-mcp-not-cli-for-capture-2026-06-09

## decision

Knowledge capture ships in the borg-collective plugin via a stateless Stop hook (curl to /mcp/), not in the cairn CLI repo.

## context

Evaluated three placement options: cairn CLI, borg plugin, or separate capture service.

## reasoning

Adding capture to the CLI creates bidirectional coupling and forces a CLI install wherever capture runs. The plugin already has a Stop hook; curl to MCP is stateless and requires no install.
