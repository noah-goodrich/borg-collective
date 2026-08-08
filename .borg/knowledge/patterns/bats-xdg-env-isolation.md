---
id: bats-xdg-env-isolation
project: borg-collective
domain: testing
tags:
- bats
- bash
- xdg
- environment
- test-isolation
preconditions: []
steps:
- In bats setup(), set HOME to a temp directory.
- Also explicitly set XDG_CONFIG_HOME to `$HOME/.config` (or the desired temp path)
  to prevent leakage from the outer shell environment.
- Verify any tool that uses XDG_CONFIG_HOME recomputes derived paths (e.g., BORG_DIR)
  after the override.
- Add a regression test that sets XDG_CONFIG_HOME to a non-existent directory and
  confirms the behavior under test does not emit unexpected stderr.
pitfalls:
- XDG_CONFIG_HOME set in the developer's shell session will bleed into bats tests
  even when HOME is overridden — the two are independent env vars.
- Bash opens redirect targets before executing the command body; a missing directory
  causes a stderr open-error that precedes 2>/dev/null suppression on the command
  itself.
- bats `run` captures both stdout and stderr into $output; a stray stderr line can
  corrupt structured output like JSON, producing cryptic jq parse errors rather than
  obvious test failures.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260714-1747-borg-collective
superseded_by: null
created_at: '2026-07-14 17:49:55.808247+00:00'
updated_at: '2026-07-14 17:49:55.808248+00:00'
---

# bats-xdg-env-isolation

## description

When bats setup overrides HOME for test isolation, XDG_CONFIG_HOME must also be explicitly set (or unset), because tools that compute config paths via `${XDG_CONFIG_HOME:-$HOME/.config}` will still use the pre-test XDG_CONFIG_HOME if it was set in the outer environment, pointing to paths that don't exist in the test sandbox.
