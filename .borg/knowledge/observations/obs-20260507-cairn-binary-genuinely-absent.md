---
id: obs-20260507-cairn-binary-genuinely-absent
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- cairn
- PATH
- binary
- SessionStart
- pipx
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.350201+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260507-cairn-binary-genuinely-absent

## content

SessionStart hook prints CAIRN UNAVAILABLE not because of a PATH misconfiguration but because the cairn binary is genuinely not installed on the machine. `command -v cairn` returns nothing. This was confirmed by a verification spike.

## resolution

Install via `pipx install cairn` (not dotfiles). Verify with `command -v cairn` after install. Directive filed at `cairn/docs/plans/directives/2026-05-07-cairn-restoration.md`.
