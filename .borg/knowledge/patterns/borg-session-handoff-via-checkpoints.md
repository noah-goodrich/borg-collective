---
id: borg-session-handoff-via-checkpoints
project: borg-collective
domain: workflow
tags:
- borg
- checkpoint
- borg-start
- borg-stop
- session-continuity
preconditions: []
steps:
- Remove the Sonnet API call from `hooks/borg-stop.sh`; ensure checkpoint is written
  before hook exits
- 'In `hooks/borg-start.sh`, locate newest checkpoint: `$(ls -t .borg/checkpoints/*.md
  2>/dev/null | head -1)`'
- Surface checkpoint content (or timestamp) in `borg link` deep-dive (show 3 newest)
  and `borg init` morning briefing
- Delete `~/.config/borg/debriefs/` once handoff is verified working
pitfalls:
- If no checkpoint exists (fresh repo), `ls -t .borg/checkpoints/*.md` returns nothing
  — start hook must handle the empty case gracefully
- Debriefs and checkpoints may coexist during the transition window; start hook must
  not accidentally read a stale debrief as if it were a checkpoint
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.321632+00:00'
updated_at: '2026-06-11 22:41:19.321633+00:00'
---

# borg-session-handoff-via-checkpoints

## description

Replace debrief-based session handoff with direct checkpoint reads: stop hook writes a checkpoint, start hook reads the newest checkpoint to resume context.
