---
id: obs-20260708-blind-review-catches-self-check-misses
session_date: '2026-07-08'
project: borg-collective
tool: claude-code
tags:
- skill-distillation
- verification
- blind-review
- self-check
- llm-limitation
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260708-1940-orchestrator
superseded_by: null
created_at: '2026-07-08 19:41:01.408523+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-blind-review-catches-self-check-misses

## content

When distilling a skill file, the authoring model's self-check failed to detect 6 dropped behavioral clauses that a blind Sonnet operational review (different model instance, no shared context) caught. The authoring model had context bias — it 'knew' what the clauses were supposed to say and read them as present even when they were absent.

## resolution

Mandatory independent blind review by a separate model instance with no distillation context is now part of the skill distillation pattern. This is not optional — the session empirically demonstrated that self-check alone is insufficient for load-bearing behavioral config files.
