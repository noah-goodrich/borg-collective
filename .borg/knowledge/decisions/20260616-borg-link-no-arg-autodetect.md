---
id: 20260616-borg-link-no-arg-autodetect
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- borg-link
- skills
- project-detection
- .borg-project
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.418658+00:00'
updated_at: '2026-06-16 10:27:02.418659+00:00'
---

# 20260616-borg-link-no-arg-autodetect

## decision

borg-link with no args uses .borg-project marker file to decide between deep-dive (marker present) and overview (no marker)

## context

Users running borg-link from a project root expected context-aware behavior; always defaulting to overview was unhelpful when already inside a project

## reasoning

.borg-project is already the established project-root signal in this ecosystem; reusing it avoids a new convention and keeps behavior predictable
