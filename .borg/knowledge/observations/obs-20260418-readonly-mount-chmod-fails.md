---
id: obs-20260418-readonly-mount-chmod-fails
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- docker
- bind-mount
- ssh
- chmod
- read-only
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.275366+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-readonly-mount-chmod-fails

## content

Running 'chmod 600 /home/dev/.ssh/*' in postCreateCommand on files that are bind-mounted :ro returns 'Read-only file system' error. This silently (or loudly) breaks container startup scripts that depend on the chmod succeeding, and leaves SSH key permissions unchanged.

## resolution

Remove chmod calls from postCreateCommand for :ro mounted files. Instead, ensure host-side files have correct permissions, and create the mount-point directory with correct ownership in the Dockerfile image layer using 'install -d -o dev -g dev -m 700'.
