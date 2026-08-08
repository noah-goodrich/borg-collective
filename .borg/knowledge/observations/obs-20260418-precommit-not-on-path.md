---
id: obs-20260418-precommit-not-on-path
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- pre-commit
- git
- PATH
- venv
- pipx
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.176418+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-precommit-not-on-path

## content

pre-commit hooks failed in reveal, pytest-coverage-impact, and snowfort because the pre-commit binary was not on PATH in the active shell. This left the ssh-agent fix uncommitted in those three repos despite the change being correct and already committed in sibling repos (ingle, snowfort-scaffold-bak).

## resolution

Install pre-commit globally via `pipx install pre-commit` on the host, then retry commits. Alternatively activate each project's venv before committing. Do not use --no-verify as a shortcut per project rules.
