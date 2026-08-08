---
id: obs-20260611-checkpoint-timestamped-file
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- checkpoint
- skills
- persistence
- file-layout
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.969339+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-checkpoint-timestamped-file

## content

Checkpoint skill was updated to write files at `<project>/.borg/checkpoints/<YYYY-MM-DD-HHMM>.md` rather than overwriting a single file. This enables checkpoint history and makes it easier to diff progress across sessions.

## resolution

No issue — this is the intended design. Consumers of checkpoint data should glob the directory rather than reading a fixed filename.
