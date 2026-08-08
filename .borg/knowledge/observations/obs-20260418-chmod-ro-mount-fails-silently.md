---
id: obs-20260418-chmod-ro-mount-fails-silently
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- docker
- bind-mount
- chmod
- ssh
- permissions
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.061979+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-chmod-ro-mount-fails-silently

## content

chmod on files inside a :ro Docker bind-mount exits with 'Read-only file system' error (errno EROFS). If this is in postCreateCommand without error handling, it can silently fail or cause the entire postCreateCommand to abort, leaving SSH broken. The symptom is that SSH files appear to exist but auth fails — it's easy to misdiagnose as a key or agent problem.

## resolution

Remove chmod from postCreateCommand for :ro mounted files. Ensure correct permissions exist on the host before mounting. The container only needs read access to SSH config/known_hosts anyway.
