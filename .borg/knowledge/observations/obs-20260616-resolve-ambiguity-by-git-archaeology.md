---
id: obs-20260616-resolve-ambiguity-by-git-archaeology
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- history
- source-of-truth
- decision-archaeology
- dispatch
category: pattern_discovered
files_involved: []
confidence: 0.8
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.410579+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-resolve-ambiguity-by-git-archaeology

## content

A source-of-truth ambiguity that had persisted across multiple sessions was resolved in minutes by tracing git history to the founding Dispatch session commit (f9ef8d07, 2026-05-24). The original decision was already recorded; it just had not been surfaced.

## resolution

When architectural questions feel unresolved, search git log for the earliest commit that introduced the relevant concept before assuming the decision was never made. Use git log --all --grep or git log -S to find the originating session.
