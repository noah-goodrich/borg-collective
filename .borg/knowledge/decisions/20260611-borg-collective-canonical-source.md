---
id: 20260611-borg-collective-canonical-source
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- repo-structure
- source-of-truth
- claude-plugins
- distribution
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.459760+00:00'
updated_at: '2026-06-11 22:41:19.459760+00:00'
---

# 20260611-borg-collective-canonical-source

## decision

borg-collective is canonical source of truth; claude-plugins distributes only the publishable subset

## context

There was ambiguity about which repo owned the canonical versions of skills/hooks. A backwards directive existed in claude-plugins. Found original Dispatch session (f9ef8d07) that confirmed the intended direction.

## reasoning

borg-collective contains private/project-specific config that should not be published; claude-plugins is a downstream distribution artifact, not an upstream source
