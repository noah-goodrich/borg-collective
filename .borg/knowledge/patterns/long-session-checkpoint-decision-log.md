---
id: long-session-checkpoint-decision-log
project: borg-collective
domain: process
tags:
- orchestration
- session-management
- borg-collective
- documentation
preconditions: []
steps:
- Create .borg/decisions/YYYY-MM-DD-session.md at session start; log each significant
  architectural or data decision as it is made
- Write .borg/checkpoints/ files at natural pause points (e.g., after each project
  milestone) with current state and pending actions
- 'At session end, commit .borg/ artifacts with a chore: commit separate from code
  changes'
- Next session reads decision log and checkpoints before touching any code to avoid
  re-litigating settled decisions
pitfalls:
- If checkpoints are not committed before a crash or context reset, the next session
  has no recovery point and must re-audit all projects
- Decision log must record what was NOT done (e.g., 'dummy data confirmed never in
  prod') as explicitly as what was done — omissions are the most common source of
  re-work
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.266453+00:00'
updated_at: '2026-06-16 10:27:02.266454+00:00'
---

# long-session-checkpoint-decision-log

## description

For multi-hour unattended orchestration sessions, maintain a structured decision log and checkpoint files in .borg/ so the next session can resume without re-reading full conversation history
