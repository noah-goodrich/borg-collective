---
id: audit-mcp-tool-calls-from-jsonl
project: borg-collective
domain: infrastructure
tags:
- claude
- mcp
- debugging
- jsonl
- supabase
- allowlist
preconditions: []
steps:
- 'Run: jq -r ''..|.name? // empty'' ~/.claude/projects/<slug>/*.jsonl | grep -i supabase
  | sort | uniq -c | sort -rn'
- Review the frequency-ranked list to distinguish high-friction read-only tools from
  high-risk mutating tools
- Cross-reference tool names against MCP server docs to confirm read-only vs. mutating
  classification
- Add confirmed read-only tools alphabetically to the allowList array in ~/.claude/settings.json
- 'Validate JSON after editing: jq . ~/.claude/settings.json > /dev/null'
- Optionally restart Claude / the affected project session for changes to take effect
pitfalls:
- execute_sql appears frequently in call history but is mutating — frequency alone
  is not sufficient signal for allowlisting
- JSONL history for sessions running inside drone containers (e.g. under /workspace)
  never lands on the host, so those sessions will be invisible to this audit
- Sorting alphabetically matters if the settings file has ordering conventions — inserting
  out of order may cause review friction even though JSON itself is order-agnostic
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.294922+00:00'
updated_at: '2026-06-11 22:41:19.294923+00:00'
---

# audit-mcp-tool-calls-from-jsonl

## description

Identify which MCP tools are generating permission prompts by mining Claude session JSONL history, so allowlist decisions are data-driven rather than speculative
