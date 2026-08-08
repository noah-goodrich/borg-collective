---
id: obs-20260616-debrief-vs-checkpoint-redundancy
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- session-lifecycle
- checkpoint
- debrief
- llm-cost
- signal-quality
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.213048+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-debrief-vs-checkpoint-redundancy

## content

Auto-generated LLM debriefs (produced by running Sonnet over session tool calls at stop time) are lower signal than operator-written checkpoints because they summarize what happened mechanically rather than capturing what the operator deemed important to preserve. Once a deliberate checkpoint skill exists, the debrief system is strictly redundant and adds LLM cost on every session end.

## resolution

Delete the debrief skill and remove the LLM call from the stop hook. SessionStart reads the newest checkpoint file instead. Accept that sessions without a checkpoint will start cold — treat this as useful feedback that encourages operators to checkpoint before ending sessions.
