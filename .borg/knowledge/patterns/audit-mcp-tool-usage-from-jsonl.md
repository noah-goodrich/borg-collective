---
id: audit-mcp-tool-usage-from-jsonl
project: borg-collective
domain: infrastructure
tags:
- claude
- mcp
- jsonl
- audit
- allowlist
- permissions
preconditions: []
steps:
- 'Locate Claude project JSONL logs: ~/.claude/projects/<slug>/*.jsonl'
- 'Extract all tool_use names: jq -r ''..|.name? // empty'' ~/.claude/projects/<slug>/*.jsonl
  | grep -i <tool-prefix>'
- Tally frequency to identify high-friction read-only ops vs. rare mutating ops
- Add confirmed read-only tools to ~/.claude/settings.json allowlist, alphabetically
  ordered
- 'Verify valid JSON post-edit: jq . ~/.claude/settings.json'
pitfalls:
- In-container projects (e.g., ingle running inside a drone container at /workspace)
  will have no host-side JSONL history — grep will return nothing, giving a false
  impression of zero usage
- Tool names in JSONL are nested; a shallow jq select will miss them — use the recursive
  descent (..|.name? // empty) form
- ~/.claude/settings.json is outside any project repo and not git-tracked; changes
  are invisible to normal repo hygiene checks
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.089175+00:00'
updated_at: '2026-06-11 20:39:25.089175+00:00'
---

# audit-mcp-tool-usage-from-jsonl

## description

Determine which MCP tools are actually being invoked in Claude sessions before modifying allowlists, to make evidence-based decisions rather than guessing.
