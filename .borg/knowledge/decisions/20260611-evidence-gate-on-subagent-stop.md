---
id: 20260611-evidence-gate-on-subagent-stop
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- hooks
- agents
- evidence
- quality-gate
- jsonl
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.500811+00:00'
updated_at: '2026-06-11 22:41:19.500812+00:00'
---

# 20260611-evidence-gate-on-subagent-stop

## decision

Score last_assistant_message 0–3 for evidence signals (file-path citations, git diff presence) and append evidence_found/evidence_score to every agents.jsonl record at SubagentStop

## context

Research identified that subagent outputs were being logged without any quality signal, making it impossible to distinguish substantive responses from hallucinated ones.

## reasoning

A lightweight numeric score embedded in the existing JSONL record is queryable by borg watch and other tooling without schema changes. Boolean evidence_found enables fast filtering; the 0–3 score enables finer ranking. stderr warning keeps the gate non-blocking while still surfacing issues.
