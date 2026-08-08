---
id: 20260616-gitignore-exemption-ordering
date: '2026-06-16'
project: borg-collective
domain: code-quality
tags:
- gitignore
- git
- borg
- checkpoints
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.227408+00:00'
updated_at: '2026-06-16 10:27:02.227409+00:00'
---

# 20260616-gitignore-exemption-ordering

## decision

Removed `.borg/` blanket-ignore line so that `!.borg/checkpoints/` exemption becomes reachable

## context

`.gitignore` had `.borg/` on a line before `!.borg/checkpoints/`, which made git ignore the negation entirely — checkpoints were never tracked despite the explicit exemption

## reasoning

Git processes `.gitignore` rules top-to-bottom; a parent directory ignore cannot be un-ignored for a subdirectory. Removing the blanket ignore (or reordering so the negation comes first and applies only to the subdirectory) is the only way to make the exemption work.
