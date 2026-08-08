---
id: 20260527-borg-source-of-truth-model
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- borg-collective
- claude-plugins
- privacy
- repository-structure
- canonical-source
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.407460+00:00'
updated_at: '2026-06-16 10:27:02.407461+00:00'
---

# 20260527-borg-source-of-truth-model

## decision

borg-collective is the canonical source of truth; claude-plugins distributes only the publishable subset

## context

There was ambiguity about which repo owned the authoritative version of shared docs/plans. The session resolved this by tracing back to the original Dispatch session (f9ef8d07, 2026-05-24) that established the model.

## reasoning

Privacy boundary was already defined in the founding session — borg-collective holds everything including private context; claude-plugins is a filtered distribution layer. Edits flow borg-collective → claude-plugins, never the reverse.
