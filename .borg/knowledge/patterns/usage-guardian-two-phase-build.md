---
id: usage-guardian-two-phase-build
project: borg-collective
domain: architecture
tags:
- hooks
- usage-guardian
- shell
- safety
- claude-code
preconditions: []
steps:
- 'Phase 1 (soft): Add a sweep function to the usage-watch poller that fires when
  samples cross the lower threshold; deliver a /borg-link-up signal to active drone
  panes. Covered by existing poller test suite.'
- 'Phase 2 (hard): Implement a PreToolUse hook (matcher Agent|Workflow) that reads
  the latest sample from the shared samples file and exits 2 (deny) only when armed
  AND sample is fresh AND value >= hard threshold. Fail-OPEN on any uncertainty.'
- 'Wire both into build-plugin.sh: hooks.json entry with correct matcher + copy to
  dist list. Assert wiring with a source-parity bats test.'
- Ship both default-OFF (separate enable env vars); document the live-cap validation
  requirement before closing the directive.
- 'Live-cap validation: arm both halves, confirm sweep fires at 85% and dispatch is
  actually blocked at 92% by the Claude Code runner (not just by bats). Do not tune
  thresholds until 3+ near-cap episodes.'
pitfalls:
- Bats tests only prove the hook script emits the correct exit code — they do NOT
  prove Claude Code honors PreToolUse exit 2 as a veto. Live validation is mandatory.
- A single near-cap data point is insufficient to calibrate thresholds. Collect 3+
  episodes before adjusting.
- Squash-merging a feature branch with multiple open PRs pointing to it leaves orphaned
  open PRs that must be manually closed.
- The hard-stop hook must never block on data-source uncertainty (missing file, stale
  sample, parse error) — any such condition must fall through to OPEN/allow.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-25 16:56:41.543207+00:00'
updated_at: '2026-07-25 17:54:08.545920+00:00'
---

# usage-guardian-two-phase-build

## description

Build a two-phase usage cap guardian: a soft checkpoint sweep at a lower threshold (85%) that notifies active panes, followed by a hard-stop veto hook at a higher threshold (92%) that denies new dispatch. Both are default-OFF and fail-OPEN.
