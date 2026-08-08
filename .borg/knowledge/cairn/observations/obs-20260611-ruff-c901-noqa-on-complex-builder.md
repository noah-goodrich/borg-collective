---
id: obs-20260611-ruff-c901-noqa-on-complex-builder
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- ruff
- complexity
- noqa
- mcp
- code-quality
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.018171+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-ruff-c901-noqa-on-complex-builder

## content

The `build_mcp_server` function in cairn exceeded ruff's C901 complexity threshold. Rather than decomposing it (which would require restructuring MCP server wiring logic), a targeted `# noqa: C901` suppression was added with a justification comment.

## resolution

Acceptable tradeoff for a wiring/registration function where splitting into sub-functions would obscure the linear registration flow. Document the noqa so future maintainers understand it was intentional, not overlooked.
