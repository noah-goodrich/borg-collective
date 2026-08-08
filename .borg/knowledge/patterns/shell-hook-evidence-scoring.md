---
id: shell-hook-evidence-scoring
project: borg-collective
domain: hooks
tags:
- shell
- jq
- scoring
- jsonl
- quality-gate
preconditions: []
steps:
- Read hook input JSON from stdin; cache it (avoid re-reading)
- Extract the target field (e.g., last_assistant_message) with jq, defaulting to empty
  string
- 'Run _score_evidence(): award points for concrete signals (file paths matching known
  patterns, presence of diff hunks, etc.); cap at max score'
- Derive boolean evidence_found from score > 0
- Append evidence_found and evidence_score as new fields to the existing JSONL record
  using jq --argjson
- If evidence_found is false AND the message was non-empty, print a one-line warning
  to stderr (do not exit non-zero)
pitfalls:
- Using || true after jq build commands masks real jq errors; remove it and let the
  pipeline fail loudly
- Scoring regex must be anchored correctly — overly broad patterns will produce false
  positives on prose that mentions filenames
- JSONL append must be atomic enough for multi-run accumulation tests; ensure each
  run appends a complete line
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.501552+00:00'
updated_at: '2026-06-11 22:41:19.501553+00:00'
---

# shell-hook-evidence-scoring

## description

Score a text field from hook JSON input for evidence signals and append results to a JSONL log, with a non-blocking stderr warning on failure
