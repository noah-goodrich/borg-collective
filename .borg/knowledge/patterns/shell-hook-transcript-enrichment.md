---
id: shell-hook-transcript-enrichment
project: borg-collective
domain: hooks
tags:
- hooks
- cairn
- transcript
- jq
- shell
- session-stop
preconditions: []
steps:
- Receive hook input JSON; parse transcript_path with jq (.transcript_path // empty)
- 'Guard: skip enrichment silently if path is empty, file does not exist, or file
  is not readable'
- 'Extract last assistant message via jq: walk the messages array, filter role==assistant,
  take last, extract .content text'
- Cap extracted text at a safe character limit (e.g., 800 chars) to avoid CLI argument
  length issues
- Supplement with repo context (e.g., git log --oneline -3) formatted as markdown
  sections
- Pass assembled markdown string as --notes to the external system's record command
pitfalls:
- grep+sed extraction of quoted JSON strings stops at the first embedded quote, silently
  producing truncated content — always use jq for JSON field extraction
- Transcript files can be large; always cap extracted content before passing as a
  CLI argument
- Missing or unreadable transcript_path must be a silent no-op, not an error — hooks
  must not fail agent execution
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.466745+00:00'
updated_at: '2026-06-16 10:27:02.466745+00:00'
---

# shell-hook-transcript-enrichment

## description

Pattern for enriching an external record-keeping system at SessionStop using structured content extracted from a Claude transcript file
