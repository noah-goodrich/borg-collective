---
id: supabase-mcp-prompt-triage
project: borg-collective
domain: infrastructure
tags:
- claude-code
- mcp
- supabase
- debugging
- allowlist
preconditions: []
steps:
- 'Extract tool names from the relevant project''s session JSONL: jq -r ''..|.name?
  // empty'' ~/.claude/projects/<slug>/*.jsonl | grep -i supabase'
- Tally call frequency to understand which tools are the dominant prompt sources
- Classify each tool as read-only (get_*, list_*, generate_typescript_types, search_docs)
  or mutating (execute_sql, apply_migration, lifecycle ops)
- Add read-only tools to ~/.claude/settings.json allowlist, inserted alphabetically
  to maintain readability
- 'Validate JSON after editing: jq . ~/.claude/settings.json'
- Leave mutating tools gated; revisit only if specific use-case justifies the risk
pitfalls:
- execute_sql appears frequently in session logs and feels like a candidate for allowlisting,
  but it can run arbitrary writes — confirm intent before promoting
- The JSONL path uses a project slug derived from the project directory; verify the
  slug matches with borg ls or by inspecting ~/.claude/projects/
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.200938+00:00'
updated_at: '2026-06-16 10:27:02.200939+00:00'
---

# supabase-mcp-prompt-triage

## description

Identify which Supabase MCP tool is causing permission prompts in a Claude session, then decide whether it's safe to allowlist
