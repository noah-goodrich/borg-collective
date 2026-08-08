---
id: verify-gated-directive-audit
project: borg-collective
domain: process
tags:
- directives
- backlog-hygiene
- adversarial-verify
- workflow
preconditions: []
steps:
- 'For each open directive: investigator independently checks the cited code, commit
  hashes, and acceptance criteria without assuming the directive''s stated status
  is accurate.'
- Skeptic reviews the investigator's findings and explicitly attempts to falsify each
  conclusion (e.g., 'is there another commit that actually fixed this?').
- Only if investigator and skeptic agree does the status change (NOT_DONE / DONE /
  PARTIAL).
- 'For DONE-but-un-archived: assimilate directly without reopening work.'
- 'For PARTIAL: split into shipped ACs (close) and open ACs (update directive in place).'
- 'For NOT_DONE: fix, then assimilate in the same PR that contains the fix.'
pitfalls:
- 'A prior commit described as ''the fix'' may address a *different* bug with a similar
  name (as happened with commit #48 for reaper-TZ — it was a `stat` fix, not the UTC
  parsing fix).'
- A directive may be marked open simply because no one archived it after the work
  shipped; always check the actual code and test suite before scheduling re-work.
- Partial completion is easy to mistake for done if only the most-visible ACs are
  checked; verify every AC individually against code/tests.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.559955+00:00'
updated_at: '2026-06-11 22:41:19.559955+00:00'
---

# verify-gated-directive-audit

## description

Two-agent pattern (investigator + skeptic) for auditing whether open backlog directives are genuinely open, done-but-un-archived, or partially complete — before actioning any of them.
