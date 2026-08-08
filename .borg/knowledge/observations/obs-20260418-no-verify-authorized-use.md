---
id: obs-20260418-no-verify-authorized-use
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- git
- pre-commit
- hooks
- devcontainer
- workflow
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.276700+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-no-verify-authorized-use

## content

Using 'git commit --no-verify' is authorized for devcontainer-only changes (changes that don't affect runtime application code). This was explicitly noted in the session for the selective ~/.ssh mount fix commits in reveal, pytest-coverage-impact, and snowfort.

## resolution

Document this as a team convention: --no-verify is acceptable when the change scope is strictly devcontainer configuration and the committer has verified the change manually. Not acceptable for application code changes.
