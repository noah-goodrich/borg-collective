---
id: 20260611-drop-conflicting-commits-on-rebase
date: '2026-06-11'
project: borg-collective
domain: git-workflow
tags:
- git
- rebase
- pr-management
- conflict-resolution
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.467595+00:00'
updated_at: '2026-06-11 22:41:19.467595+00:00'
---

# 20260611-drop-conflicting-commits-on-rebase

## decision

For PR #21, prefer rebasing onto main and explicitly dropping the 3 commits that already landed via PR #29, rather than closing and reopening a new PR

## context

PR #21 contained both orchestrator-mode commits (still unmerged) and borg-plan-promote commits (already merged via PR #29), making it unmergeable without conflict

## reasoning

Interactive rebase with dropped commits is cleaner than a new PR; preserves review history and keeps the 5 valid commits intact. Alternative of closing and opening new PR is also acceptable and may be cleaner if review context has drifted.
