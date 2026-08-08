---
id: security-audit-sonnet-triage-fable
project: borg-collective
domain: security
tags:
- security-audit
- multi-model
- cost-optimization
- triage
preconditions: []
steps:
- Run multiple cheap Sonnet reviewer instances in parallel across the codebase to
  generate a raw issue list.
- Deduplicate and normalize the raw list.
- Route the deduplicated list to the highest-capability model (Fable/Opus) for severity
  triage, root-cause confirmation, and fix specification.
- Output a triaged document with severity, file:line references, fix specs, and gating
  conditions (e.g., tests required before fix).
- Queue fixes as discrete nanoprobe jobs; do not apply fixes during the audit pass.
pitfalls:
- Cheap models generate false positives; do not act on raw Sonnet findings without
  Fable/Opus triage.
- Specifying fixes during the audit is tempting but risky — fixes without tests on
  security-critical hooks can disable protections rather than strengthen them.
- Ensure the triaged output includes file:line references for every finding; vague
  descriptions delay the fix phase.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260708-1940-orchestrator
superseded_by: null
created_at: '2026-07-08 19:41:01.404418+00:00'
updated_at: '2026-07-08 19:41:01.404418+00:00'
---

# security-audit-sonnet-triage-fable

## description

Cost-efficient security audit pattern: cheap models do broad discovery, expensive model does triage and prioritization only.
