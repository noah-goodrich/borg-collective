---
id: obs-20260527-mcp-streamable-http-same-process
session_date: '2026-05-27'
project: cairn
tool: cursor
tags:
- mcp
- fastapi
- streamable-http
- architecture
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.009504+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-mcp-streamable-http-same-process

## content

MCP tools can be served over Streamable HTTP on the same FastAPI process as the REST API (mounted at `/mcp`), with no separate process or port required. This works because FastAPI's ASGI routing can mount the MCP handler as a sub-application alongside existing REST routes.

## resolution

Use this pattern when adding MCP to an existing FastAPI service. Mount point should be documented in the borg-plugin-contract so consumers know the URL without discovery overhead.
