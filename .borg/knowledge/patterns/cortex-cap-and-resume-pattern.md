---
id: cortex-cap-and-resume-pattern
project: borg-collective
domain: session-management
tags:
- cortex
- claude
- tmux
- session-cap
- wake
preconditions: []
steps:
- Claude emits a recognizable cap message when approaching context limit
- Session pauses — Claude stops responding to new input
- Operator (or daemon) sends `wake up!` to the Claude pane via `tmux send-keys`
- Claude resumes from where it left off, continuing the in-progress task
- Repeat as needed; multiple cap-hits per session are normal for long tasks
pitfalls:
- Without automation, operator must be present to send the wake signal — creates a
  synchronous dependency on human availability
- If the wake signal is not sent, the task stalls indefinitely with no visible error
- Cap message format must be stable for a detector daemon to trigger reliably
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.356694+00:00'
updated_at: '2026-06-11 22:41:19.356695+00:00'
---

# cortex-cap-and-resume-pattern

## description

When Claude (Cortex) hits a context/token cap mid-task, the session pauses waiting for a wake signal; manually sending `wake up!` via tmux resumes mid-task with no state loss
