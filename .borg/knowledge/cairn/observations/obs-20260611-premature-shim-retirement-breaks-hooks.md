---
id: obs-20260611-premature-shim-retirement-breaks-hooks
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- cairn
- shim
- dotfiles
- hooks
- regression
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.027018+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-premature-shim-retirement-breaks-hooks

## content

The dotfiles cairn shim was retired during this session under the assumption the Python CLI fully superseded it. This immediately broke all three hook integrations (borg-collective, reveal, cairn) which depend on the shim being present in the dotfiles bin directory. All three reported CAIRN UNAVAILABLE until the shim was restored.

## resolution

Restored the shim. Documented that shim and Python CLI serve different runtime contexts and must coexist. Added the decision record to prevent recurrence.
