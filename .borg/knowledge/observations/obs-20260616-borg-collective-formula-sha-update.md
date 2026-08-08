---
id: obs-20260616-borg-collective-formula-sha-update
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- homebrew
- formula
- sha256
- release-process
- borg-collective
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.335700+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-borg-collective-formula-sha-update

## content

The borg-collective release process requires updating sha256 in Formula/borg-collective.rb as a distinct commit after tagging and pushing. Forgetting this leaves the Homebrew formula pointing to the wrong artifact hash.

## resolution

Treat the formula sha256 update as a mandatory release checklist step: tag → push tag → compute new sha256 → update formula → commit formula separately (as done in bee12b8).
