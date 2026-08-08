---
id: obs-20260428-devnet-cross-container-reachability
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- docker
- devnet
- networking
- devcontainer
- cross-container
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.709928+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260428-devnet-cross-container-reachability

## content

Containers on the devnet Docker network can reach the cairn API service at `cairn-api:8767` by service name. Verified from both `reveal-reveal-app-1` and `cairn-cairn-app-1`. The service name in docker-compose resolves correctly across compose projects as long as both are on the same external network.

## resolution

No fix needed — use `http://cairn-api:8767` as the CAIRN_API_URL in all devcontainer environments. Host uses localhost:8767.
