---
id: zero-row-silence-detection
project: borg-collective
domain: observability
tags:
- polling
- jsonl
- observability
- audit-trail
preconditions: []
steps:
- Capture both stdout and stderr of the inner command (e.g., claude /usage)
- Always write one row to the output file regardless of success/failure
- Include a status field (ok|idle|suspect|error) and a reason field in every row
- Log truncated raw output (e.g., 400 chars) on failure statuses for post-hoc diagnosis
- Define 'suspect' as independent cross-measurement disagreement (e.g., pgrep vs.
  pane name) so the bug self-reports
pitfalls:
- Suppressing stderr with 2>/dev/null before the write step destroys the only evidence
  of why a poll failed
- Using || output='' after the command silently swallows non-zero exits — the row
  never gets written
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260709-1659-borg-collective
superseded_by: null
created_at: '2026-07-09 17:01:17.385642+00:00'
updated_at: '2026-07-09 17:01:17.385643+00:00'
---

# zero-row-silence-detection

## description

Making a poller's silence unambiguous by guaranteeing exactly one output row per invocation.
