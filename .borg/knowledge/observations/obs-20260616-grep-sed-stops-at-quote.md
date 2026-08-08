---
id: obs-20260616-grep-sed-stops-at-quote
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- shell
- grep
- sed
- json-parsing
- transcript
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.468326+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-grep-sed-stops-at-quote

## content

Using grep+sed to extract a quoted string from JSON (e.g., grep 'content' | sed 's/.*": "//; s/".*//') stops at the first double-quote character inside the value. Any assistant message containing code, filenames, or quoted terms will be silently truncated at the first embedded quote. The tool appears to work on simple test inputs but fails on real-world content.

## resolution

Always use jq for JSON field extraction. For potentially large values, pipe through a length-cap step (e.g., jq '... | .[0:800]') rather than relying on sed ranges.
