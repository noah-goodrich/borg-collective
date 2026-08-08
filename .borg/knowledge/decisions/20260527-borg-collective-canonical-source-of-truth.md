---
id: 20260527-borg-collective-canonical-source-of-truth
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg-collective
- claude-plugins
- source-of-truth
- privacy
- monorepo
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.452470+00:00'
updated_at: '2026-06-11 22:41:19.452471+00:00'
---

# 20260527-borg-collective-canonical-source-of-truth

## decision

borg-collective is the canonical source of truth; claude-plugins distributes only the publishable subset

## context

There was ambiguity about which repo owned the authoritative state. A previous Dispatch session (f9ef8d07, 2026-05-24) had already resolved this but the decision was not surfaced in handoff docs.

## reasoning

Privacy boundary requires that not everything in borg-collective is publishable. claude-plugins is a distribution target, not the source. Keeping canonical state in borg-collective prevents accidental disclosure and clarifies edit direction.
