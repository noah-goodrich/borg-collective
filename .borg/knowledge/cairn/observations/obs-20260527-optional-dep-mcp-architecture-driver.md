---
id: obs-20260527-optional-dep-mcp-architecture-driver
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- borg-collective
- mcp
- optional-dependency
- architecture-principle
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.718790+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-optional-dep-mcp-architecture-driver

## content

The stillpoint cross-project principle 'optional dependency, never required install' directly drove the choice of MCP over HTTP as the borg-collective integration mechanism. When a consuming plugin must degrade gracefully if a service is absent, an HTTP/MCP interface with connection-attempt-and-fallback is more reliable than host PATH detection or import-time optional imports.

## resolution

Apply this pattern whenever a borg-collective plugin integrates with an optional service: define an MCP or REST contract, attempt connection at plugin invocation time, and degrade gracefully on connection failure. Document the contract in docs/integrations/ of the service repo.
