---
id: obs-20260715-usage-cap-single-episode
session_date: '2026-07-15'
project: borg-collective
tool: claude-code
tags:
- usage-guardian
- phase-2
- data-readiness
- near-cap
- burn-rate
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260715-0256-borg-collective
superseded_by: null
created_at: '2026-07-15 02:57:12.426734+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-usage-cap-single-episode

## content

Analysis of 3080 rows (~6 days) in ~/.local/state/borg/usage-samples.jsonl showed only ONE near-cap episode (all ≥85% samples from Jul 9). Burn rate accelerates ~4× near the cap (~1%/min in the 85→93% band). With only one episode, the ≥85% checkpoint sweep threshold cannot be reliably tuned — at least 3 independent near-cap episodes are needed before setting that parameter.

## resolution

Do not tune the sweep threshold until 3+ independent near-cap episodes are logged. The Phase-2 directive (docs/plans/directives/2026-07-08-usage-guardian-build.md) was annotated with a 'Data-readiness note' to prevent re-deriving this in the next session.
