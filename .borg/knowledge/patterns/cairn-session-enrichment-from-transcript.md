---
id: cairn-session-enrichment-from-transcript
project: borg-collective
domain: hooks
tags:
- cairn
- hooks
- transcript
- session-notes
- git
preconditions: []
steps:
- Extract transcript_path from hook input JSON with jq; guard for empty/null
- Verify file exists and is readable before attempting parse
- Extract last assistant message via single jq path (do NOT use grep+sed pre-pass)
- Cap extracted message at a safe character limit (800 chars) to avoid argument-length
  issues
- Run git log --oneline -3 to get recent commit context
- 'Compose --notes as a markdown string: ## Recent commits + ## Last assistant message
  sections'
- Pass --notes to cairn record session; fall through silently on any guard failure
pitfalls:
- grep+sed extraction of JSON string values stops at first quote, silently returning
  truncated data — use jq exclusively
- Uncapped message length can exceed shell argument limits on long sessions
- Missing transcript file must be a silent fallback, not an error exit, because hook
  failures block the agent
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.501897+00:00'
updated_at: '2026-06-11 22:41:19.501897+00:00'
---

# cairn-session-enrichment-from-transcript

## description

At SessionStop, parse the transcript path from hook input and build structured --notes for cairn record session containing recent commits and last assistant message
