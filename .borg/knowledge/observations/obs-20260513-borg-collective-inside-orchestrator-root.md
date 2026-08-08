---
id: obs-20260513-borg-collective-inside-orchestrator-root
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- orchestrator-mode
- session-classification
- self-referential
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.429940+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260513-borg-collective-inside-orchestrator-root

## content

The borg-collective project repository lives at ~/dev/borg-collective, which is a subdirectory of the default BORG_ORCHESTRATOR_ROOT (~/dev). This creates a self-referential trap: any substring/prefix match for orchestrator-mode detection will misclassify borg-collective development sessions as orchestrator sessions, silently suppressing project-mode registry writes and checkpoints for the tool's own development.

## resolution

The exact-match rule (decision 20260513-orchestrator-mode-exact-match) resolves this. Smoke test: cd ~/dev/borg-collective should classify as project mode. cd ~/dev should classify as orchestrator mode.
