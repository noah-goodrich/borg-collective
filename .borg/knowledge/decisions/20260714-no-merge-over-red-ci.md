---
id: 20260714-no-merge-over-red-ci
date: '2026-07-14'
project: borg-collective
domain: code-quality
tags:
- ci
- quality-gate
- claude-plugins
- bats
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260714-1733-borg-collective
created_at: '2026-07-14 17:34:17.050026+00:00'
updated_at: '2026-07-14 17:34:17.050026+00:00'
---

# 20260714-no-merge-over-red-ci

## decision

Do not merge PRs over red CI, even when the failing tests are pre-existing and unrelated to the PR's own changes.

## context

claude-plugins CI had been red since PR #30 (2026-07-09) and #31, both merged over failure. PR #33 inherited that red. The same policy failure had just been fixed on the cairn side (cairn #27).

## reasoning

Merging over red normalises broken CI, making it impossible to detect regressions introduced by future PRs. The pre-existing failures must be fixed first so the baseline is trustworthy.
