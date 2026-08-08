---
id: 20260501-orphan-prevention-backlink-strategy
date: '2026-06-11'
project: borg-collective
domain: documentation
tags:
- directives
- orphan-prevention
- workflow
- hooks
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.355601+00:00'
updated_at: '2026-06-11 22:41:19.355601+00:00'
---

# 20260501-orphan-prevention-backlink-strategy

## decision

Prevent directive orphaning via three mechanisms: `Parent plan:` back-links on every child directive, `/borg-assimilate` child-check at plan assimilation time, auto-surface unlinked directives in `borg-link-down`, and post-commit nudge in `borg-link-up`

## context

Two directives created during reveal MVP execution were never back-linked to the parent plan and were never surfaced at session start, leaving them invisible and unshipped for weeks while one actively misled users

## reasoning

Defense in depth: authoring convention (back-link) catches it at creation; assimilation hook catches it at plan closure; link-down surfaces it at session start; link-up nudges after commits. Any single layer failing still has two more.
