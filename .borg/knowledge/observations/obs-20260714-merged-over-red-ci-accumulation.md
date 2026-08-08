---
id: obs-20260714-merged-over-red-ci-accumulation
session_date: '2026-07-14'
project: borg-collective
tool: claude-code
tags:
- ci
- claude-plugins
- quality-gate
- bats
- shellcheck
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-1733-borg-collective
superseded_by: null
created_at: '2026-07-14 17:34:17.056349+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-merged-over-red-ci-accumulation

## content

claude-plugins CI was red continuously from PR #30 (2026-07-09) through PR #33 because #30 and #31 were both merged over failing tests. By the time PR #33 arrived, the baseline was so broken that it was unclear whether PR #33 itself introduced new failures or was purely inheriting pre-existing ones. The same anti-pattern had just been identified and corrected on the cairn side (cairn PR #27).

## resolution

Treat red CI as a hard blocker regardless of whether the failing tests appear related to the current PR. Fix root-cause failures before merging. The cost of fixing one pre-existing red is lower than the compounding cost of an untrusted baseline across all future PRs.
