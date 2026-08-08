---
id: 20260708-security-fixes-gated-by-tests
date: '2026-07-08'
project: borg-collective
domain: security
tags:
- bash-guard
- security
- bats
- testing
- nanoprobe
alternatives: []
applies_to: []
confidence: 0.8
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260708-1940-orchestrator
created_at: '2026-07-08 19:41:01.399103+00:00'
updated_at: '2026-07-08 19:41:01.399104+00:00'
---

# 20260708-security-fixes-gated-by-tests

## decision

Queue bash-guard security fixes as nanoprobe jobs gated by new bats regression tests; do not apply fixes directly.

## context

Security audit found a CRITICAL pre-approval bypass in hooks/bash-guard.sh:66 and ~12 matcher-gap bypasses. No bats tests exist for bash-guard today.

## reasoning

Applying security fixes to a hook with zero test coverage risks introducing regressions that could either break legitimate commands or silently widen the attack surface. Tests must come first to define and lock in expected behavior.
