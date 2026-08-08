---
id: obs-20260616-directive-assimilation-workflow
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- cairn
- directives
- assimilation
- workflow
- backlog
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.221797+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-directive-assimilation-workflow

## content

A directive can be fully satisfied (all acceptance criteria met) from a prior session while leaving its code uncommitted. The subsequent session's work is then purely: verify criteria, commit the code, and archive the directive. This two-session split is valid and the assimilation step belongs in the commit session, not the implementation session.

## resolution

No change needed — this is a workable pattern. Future sessions should check directive acceptance criteria before doing any new implementation work, as the directive may already be complete.
