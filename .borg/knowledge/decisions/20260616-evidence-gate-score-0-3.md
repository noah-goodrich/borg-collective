---
id: 20260616-evidence-gate-score-0-3
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- nanoprobe
- evidence
- hooks
- agents-jsonl
- scoring
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.465841+00:00'
updated_at: '2026-06-16 10:27:02.465842+00:00'
---

# 20260616-evidence-gate-score-0-3

## decision

Score nanoprobe evidence 0–3 (file-path citations + git diff presence) rather than binary pass/fail

## context

SubagentStop hook needed a way to flag low-evidence agent responses without hard-blocking execution

## reasoning

A graduated score lets downstream consumers (borg watch, future dashboards) surface quality signal without interrupting agent workflows. Binary would either over-block or under-signal.
