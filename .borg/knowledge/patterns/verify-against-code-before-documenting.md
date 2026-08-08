---
id: verify-against-code-before-documenting
project: borg-collective
domain: documentation
tags:
- docs-sync
- audit
- code-verification
- accuracy
preconditions: []
steps:
- For each doc claim about a command, flag, or behavior, locate the implementing source
  file.
- Read the relevant code section directly — do not infer from command names or prior
  doc versions.
- Compare code behavior to the doc claim. Note any discrepancy explicitly.
- Update the doc to match code, not the other way around (unless the code is the confirmed
  bug).
- Record each discrepancy caught as an audit finding before closing the sync task.
pitfalls:
- LLM-generated command descriptions (e.g., 'drone feature'/'toggle'/'fix') may be
  plausible-sounding guesses that don't match actual implementation — always verify.
- A feature marked 'not implemented' in old docs may already exist in code (e.g.,
  presence was live but docs said otherwise).
- CLAUDE.md 'Learned lessons' can go stale and encode behavior that has since changed
  (e.g., drone/postCreateCommand sentinel guard).
- File existence checks ('six-pager.md doesn't exist') must be done against the actual
  filesystem, not from memory or prior context.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 02:47:55.519363+00:00'
updated_at: '2026-08-01 02:47:55.519366+00:00'
---

# verify-against-code-before-documenting

## description

When syncing documentation to code, verify every behavioral claim by reading the actual source before writing or accepting the doc update. Do not trust existing docs, LLM-generated descriptions, or 'obvious' assumptions about command behavior.
