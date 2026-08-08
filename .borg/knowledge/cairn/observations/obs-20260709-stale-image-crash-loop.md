---
id: obs-20260709-stale-image-crash-loop
session_date: '2026-07-09'
project: cairn
tool: claude-code
tags:
- deployment
- alembic
- docker
- migration
- crash-loop
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-1535-cairn
superseded_by: null
created_at: '2026-07-09 15:36:29.698754+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-stale-image-crash-loop

## content

After merging migration 005, the shared cairn-api container was still running the ghcr:0.3.0 image (migration ceiling 004). When the pause-waiter restarted the container, alembic upgrade ran against a DB already stamped to 005, found the code didn't know about 005, and entered a crash-loop. The service was down until the image was rebuilt from main and the container recreated.

## resolution

Rebuilt the shared image from main (bumped compose to 0.4.0), recreated the container. To prevent recurrence: always update the compose image tag and recreate (not just restart) after publishing a new migration. Memory: project_cairn_deploy_migration_ordering.
