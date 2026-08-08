---
id: obs-20260611-zsh-string-closed-by-nested-quotes
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- zsh
- quoting
- string-assignment
- multiline
- production-bug
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.147881+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-zsh-string-closed-by-nested-quotes

## content

A multi-line zsh string assignment using double quotes (briefing_prompt="...") silently closes early if any line inside the string contains a literal double-quote character. In borg.zsh:1420-1434 the string contained '"Next Session"' which terminated the assignment at that point. The resulting broken variable caused 'file name too long' errors in borg link --brief whenever any project was in the registry — a production failure, not just a test failure.

## resolution

Escape all nested double-quotes with \" inside double-quoted zsh string assignments. Long-term fix: convert to a read -r -d '' heredoc so nested quotes are not a footgun at all.
