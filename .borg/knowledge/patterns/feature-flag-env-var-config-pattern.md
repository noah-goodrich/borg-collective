---
id: feature-flag-env-var-config-pattern
project: borg-collective
domain: infrastructure
tags:
- feature-flags
- bash
- launchd
- plist
- config
preconditions: []
steps:
- Define FEATURE_ENABLED env var; default to empty/unset (OFF) in the script
- Define threshold/config var with a safe inert default
- Gate all side-effect code on the master switch check at entry to _run_sweep or equivalent
- Document in plist/config that the var exists but leave it commented-out or absent
- Capture 'arm after validation' as an explicit next-session step so it does not get
  forgotten
pitfalls:
- If the threshold var is checked before the master switch, a misconfigured threshold
  could cause confusion even when the feature is OFF — always check master switch
  first
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:16:47.848537+00:00'
updated_at: '2026-07-21 22:16:47.848538+00:00'
---

# feature-flag-env-var-config-pattern

## description

Ship a dangerous-side-effect feature default-OFF via env var master switch; expose tunable threshold as a separate env var with a safe default; arm only after empirical validation
