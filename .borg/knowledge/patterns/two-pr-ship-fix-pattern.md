---
id: two-pr-ship-fix-pattern
project: borg-collective
domain: infrastructure
tags:
- deployment
- install
- testing
- PATH
preconditions: []
steps:
- Merge the feature PR
- Run `install.sh` from scratch (or simulate it) to confirm all new binaries are symlinked
  into `$BIN_DIR`
- Invoke the feature using bare binary names (as end users would) rather than relative/absolute
  repo paths
- If live delivery fails but unit tests pass, check whether `install.sh` was updated
  for new binaries
- Ship a targeted fix PR immediately; do not bundle with unrelated changes
pitfalls:
- Tests passing from repo root mask missing `install.sh` entries — always test via
  installed PATH
- Silent failures (process not spawned, no error) are the most dangerous class of
  install bugs
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260630-2202-borg-collective
superseded_by: null
created_at: '2026-06-30 22:03:12.819014+00:00'
updated_at: '2026-06-30 22:03:12.819015+00:00'
---

# two-pr-ship-fix-pattern

## description

When shipping a new binary-backed feature, always verify it works via the real installed PATH path (not just from repo root), and treat install-path failures as blocking bugs requiring an immediate fix PR
