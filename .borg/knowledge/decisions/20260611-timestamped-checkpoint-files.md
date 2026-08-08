---
id: 20260611-timestamped-checkpoint-files
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- checkpoint
- persistence
- skill
- borg-checkpoint
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.216464+00:00'
updated_at: '2026-06-11 22:41:19.216464+00:00'
---

# 20260611-timestamped-checkpoint-files

## decision

Write checkpoint output to `<project>/.borg/checkpoints/<YYYY-MM-DD-HHMM>.md` (timestamped files) rather than a single mutable checkpoint file

## context

Prior checkpoint skill wrote to a fixed path, meaning each run overwrote the previous checkpoint with no history.


## reasoning

Timestamped files give a recoverable audit trail of session state without requiring git commits for each checkpoint. Cheap to implement, high value for debugging interrupted sessions.

