---
id: obs-20260708-claude-pane-command-is-version
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- tmux
- claude-code
- pane_current_command
- detection
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:25:36.248954+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260708-claude-pane-command-is-version

## content

A tmux pane running Claude Code reports `pane_current_command` as its version string (e.g. `2.1.205`), not `claude`. A gate matching `/^claude$/` will count zero Claude panes even when multiple drones are active.

## resolution

Match `pane_current_command` against the version pattern (numeric semver) or use a different detection heuristic. Confirmed only by an end-to-end live run — unit tests with mocked output will not catch this.
