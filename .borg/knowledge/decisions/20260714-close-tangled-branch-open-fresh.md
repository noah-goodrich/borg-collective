---
id: 20260714-close-tangled-branch-open-fresh
date: '2026-07-14'
project: borg-collective
domain: code-quality
tags:
- git
- pr-management
- claude-plugins
- branching
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260714-1733-borg-collective
created_at: '2026-07-14 17:34:17.041860+00:00'
updated_at: '2026-07-14 17:34:17.041863+00:00'
---

# 20260714-close-tangled-branch-open-fresh

## decision

Close the tangled branch (fix/skip-cairn-for-synthetic-sessions / PR #32) and open a clean branch (chore/rebuild-plugin-0.8.8 / PR #33) rather than force-pushing onto the existing branch.

## context

PR #32 had accumulated unrelated changes and a messy history. The harness auto-classifier gates force-push and self-merge, making rewriting existing branches risky.

## reasoning

A clean branch with only the intended changes makes CI failures easier to diagnose, avoids the harness force-push gate, and produces a legible PR diff for review.
