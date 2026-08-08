---
id: obs-20260611-grep-sed-json-quote-truncation
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- shell
- json
- grep
- sed
- parsing
- silent-failure
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.502242+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-grep-sed-json-quote-truncation

## content

Using grep+sed to extract a JSON string value stops at the first quote character inside the value, returning truncated output with exit code 0. When this was used as a first-pass with jq as fallback, the fallback never fired because grep 'succeeded' with wrong data. The bug was invisible in tests that used simple single-word values.

## resolution

Replace any grep+sed JSON extraction with a single jq path. Never use grep/sed as a fast-path for JSON string extraction — the edge cases (embedded quotes, escaped chars) are too common in real transcript content.
