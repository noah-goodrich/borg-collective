---
id: obs-20260630-hand-rolled-json-escape-corruption
session_date: '2026-06-30'
project: borg-collective
tool: claude-code
tags:
- shell
- json
- encoding
- jq
- data-corruption
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260630-2202-borg-collective
superseded_by: null
created_at: '2026-06-30 22:03:12.820512+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260630-hand-rolled-json-escape-corruption

## content

Hand-rolled JSON string escaping in shell (using sed/printf/parameter expansion) silently corrupts messages containing quotes, backslashes, or special characters. The corruption is data-silent — the `pub` command exits 0 but the stored JSON is malformed or the content is wrong.

## resolution

Always use `jq --arg` or `jq -n --arg key value '$key'` for JSON encoding in shell scripts. Never construct JSON by string interpolation in shell.
