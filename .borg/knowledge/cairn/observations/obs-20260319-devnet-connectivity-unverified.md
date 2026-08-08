---
id: obs-20260319-devnet-connectivity-unverified
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
created_at: '2026-06-11 23:12:50.699244+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260319-devnet-connectivity-unverified

## content

The session ended before verifying that the cairn devcontainer can actually reach dev-postgres over the devnet network. The docker-compose.yml was updated to attach to devnet, but no connectivity test was executed. It is unknown whether devnet was up or dev-postgres was reachable at session end.

## resolution

At the start of the next session, verify connectivity: docker exec cairn psql -U dev -d postgres -c 'SELECT version()'. If devnet is not running, bring it up with the host-level docker-compose that owns it before starting the cairn devcontainer.
