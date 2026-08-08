---
id: hook-injects-context-at-session-start
project: borg-collective
domain: infrastructure
tags:
- hooks
- claude-code
- adhd-guardrails
- session-context
preconditions: []
steps:
- Write hook script to compute the state (e.g., count active+waiting projects from
  borg state files)
- Compare against a threshold env var (e.g., BORG_MAX_ACTIVE)
- Output a formatted warning block if threshold exceeded
- Deploy hook to ~/.claude/hooks/ and register for SessionStart event
- Update the relevant skill (e.g., adhd-guardrails) to define behavior when it sees
  that warning
pitfalls:
- Hook output appears before skill prompts load — skill must be written to *react*
  to the warning, not assume it generated it
- Threshold env var must be set in the shell environment where claude-code launches,
  not just in .zshrc if using a non-interactive session
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.419435+00:00'
updated_at: '2026-06-16 10:27:02.419436+00:00'
---

# hook-injects-context-at-session-start

## description

Use SessionStart hooks to inject environmental state (e.g., capacity warnings) that must appear before any skill or user prompt is processed
