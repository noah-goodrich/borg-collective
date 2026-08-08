---
id: 20260611-path-isolation-absent-binary-tests
date: '2026-06-11'
project: borg-collective
domain: testing
tags:
- bats
- PATH
- cairn
- test-isolation
- shell
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.347161+00:00'
updated_at: '2026-06-11 22:41:19.347161+00:00'
---

# 20260611-path-isolation-absent-binary-tests

## decision

Use PATH isolation in bats tests that assert behavior when cairn is absent from PATH, rather than relying on cairn genuinely being missing from the test environment

## context

Three tests were failing because cairn was present in the CI/developer PATH, so 'cairn absent' scenarios were not exercising the correct code path.

## reasoning

Explicitly overriding PATH in each 'absent' test makes the test deterministic regardless of what is installed on the host. Silent-skip semantics (no error when cairn missing) are now correctly verified.
