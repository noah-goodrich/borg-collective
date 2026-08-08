---
id: obs-20260617-plaid-sandbox-nondeterminism
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- troth
- plaid
- sandbox
- testing
- nondeterminism
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.027920+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-plaid-sandbox-nondeterminism

## content

Plaid Sandbox environments are non-deterministic — replay assertions against Sandbox Link flows can fail legitimately due to Sandbox behavior variance, not bugs. A crash-replay assertion in troth's `plaid-landing` tests was failing for this reason.

## resolution

Plaid Sandbox assertions that depend on specific response content should be loosened or skipped in CI. Reserve exact-match assertions for mocked/recorded responses, not live Sandbox calls.
