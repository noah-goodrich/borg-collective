---
id: 20260715-never-silent-supersedes-no-row
date: '2026-07-15'
project: borg-collective
domain: architecture
tags:
- usage-guardian
- phase-1
- acceptance-criteria
- never-silent-contract
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260715-0256-borg-collective
created_at: '2026-07-15 02:57:12.424915+00:00'
updated_at: '2026-07-15 02:57:12.424916+00:00'
---

# 20260715-never-silent-supersedes-no-row

## decision

Accept that the never-silent contract (an explicit error row on every poll) is a deliberate strengthening of Phase-1 criterion 2's 'no row' wording, and document this as a deviation rather than a defect

## context

Phase-1 criterion 2 specified 'no row' for certain failure states, but PR #68 introduced the never-silent contract that writes an explicit error row every poll cycle instead. The plan closeout needed to reconcile these.

## reasoning

Writing an explicit error row is strictly more observable than writing nothing; the intent of the criterion (don't silently swallow errors) is satisfied and exceeded. Suppressing it retroactively would reduce reliability.
