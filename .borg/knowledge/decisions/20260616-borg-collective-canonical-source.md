---
id: 20260616-borg-collective-canonical-source
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- repository-strategy
- source-of-truth
- claude-plugins
- multi-repo
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.417454+00:00'
updated_at: '2026-06-16 10:27:02.417454+00:00'
---

# 20260616-borg-collective-canonical-source

## decision

borg-collective is canonical source of truth; claude-plugins distributes only the publishable subset

## context

There was an ambiguous directive in claude-plugins that implied it was the authoritative repo, creating confusion about where changes should originate

## reasoning

Original Dispatch session (f9ef8d07) confirmed this split explicitly. Keeping full internal tooling in borg-collective and publishing a curated subset to claude-plugins is the correct separation of concerns
