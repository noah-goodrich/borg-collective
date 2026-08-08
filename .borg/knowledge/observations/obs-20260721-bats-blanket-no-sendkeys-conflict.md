---
id: obs-20260721-bats-blanket-no-sendkeys-conflict
session_date: '2026-07-21'
project: borg-collective
tool: claude-code
tags:
- bats
- testing
- send-keys
- tmux
- test-design
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-21 22:16:47.849372+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260721-bats-blanket-no-sendkeys-conflict

## content

A pre-existing blanket bats assertion ('send-keys must never be called in usage-watch') directly conflicts with tests for the sweep's _send_checkpoint function. The blanket test had to be replaced with a default-OFF behavioural test (assert send-keys NOT called when BORG_USAGE_SWEEP_ENABLED is unset) before the new behavioural tests could be added.

## resolution

Replace blanket prohibition tests with intent-expressing default-OFF tests. The correct contract is 'send-keys is not called when the feature is disabled', not 'send-keys is never called'.
