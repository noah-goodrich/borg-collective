---
id: obs-20260319-devcontainer-connectivity-unverified
session_date: '2026-03-19'
project: cairn
tool: cursor
tags:
- docker
- devcontainer
- devnet
- postgres
- networking
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:17.987992+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260319-devcontainer-connectivity-unverified

## content

Session ended before DB connectivity from the cairn devcontainer to dev-postgres was verified. The devnet external network and dev-postgres container may not have been running at session end. The entire SQLAlchemy/Alembic rewrite is untested against a live database.

## resolution

At next session start: (1) confirm devnet is up and dev-postgres is reachable, (2) run 'docker exec cairn psql -U dev -d postgres -c SELECT version()' to verify connectivity, (3) run alembic upgrade head, (4) run full test suite.
