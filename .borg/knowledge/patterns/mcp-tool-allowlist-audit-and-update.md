---
id: mcp-tool-allowlist-audit-and-update
project: borg-collective
domain: infrastructure
tags:
- claude
- mcp
- allowlist
- settings
- jsonl
- jq
preconditions: []
steps:
- 'Identify the Claude project slugs for the affected projects under ~/.claude/projects/
  (note: containerized projects write history inside the container, not the host).'
- 'Extract all MCP tool_use names from session history: jq -r ''..|.name? // empty''
  ~/.claude/projects/<slug>/*.jsonl | sort | uniq -c | sort -rn'
- 'Categorize each tool as read-only (safe to allowlist) or mutating (keep prompted).
  For Supabase MCP: list_*, get_*, generate_typescript_types, search_docs are read-only;
  execute_sql, apply_migration, branch/project lifecycle ops are mutating.'
- Edit ~/.claude/settings.json to add approved tools to the allowlist array, maintaining
  alphabetical order for readability.
- 'Validate JSON integrity: jq . ~/.claude/settings.json > /dev/null'
- Document which mutating tools were intentionally left out so the next session doesn't
  re-litigate the decision.
pitfalls:
- Containerized projects (e.g. drone-based) write JSONL to the container filesystem,
  not the host — their history won't appear in host slug directories, making it look
  like the project has no MCP usage when it does.
- If prompts return after allowlisting, the actual triggering tool is probably a mutating
  one (execute_sql, apply_migration) that was intentionally excluded — verify with
  the jq audit command before expanding the allowlist further.
- ~/.claude/settings.json is not tracked in any project repo; changes are silently
  local and will be lost if the home directory is reprovisioned without dotfile backup.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.290091+00:00'
updated_at: '2026-06-11 22:41:19.290092+00:00'
---

# mcp-tool-allowlist-audit-and-update

## description

Data-driven workflow for deciding which MCP tools to promote to the global Claude allowlist, based on actual session usage rather than assumptions.
