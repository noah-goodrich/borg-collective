---
id: obs-20260423-ingle-project-invisible-on-host
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- docker
- borg-ls
- drone
- workspace
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.116953+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-ingle-project-invisible-on-host

## content

Projects running entirely inside a drone container under /workspace (not bind-mounted to the host) appear as 'idle' in borg ls and have no host-side session history. This is expected behavior — the host state file is never written by a purely containerized project.

## resolution

Not a bug. Document this as expected: borg ls reflects host-visible state only. Container-internal projects are opaque to the host daemon unless their state directory is on a shared volume.
