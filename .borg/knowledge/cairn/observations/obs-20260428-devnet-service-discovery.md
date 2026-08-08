---
id: obs-20260428-devnet-service-discovery
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- docker
- devnet
- service-discovery
- devcontainers
- networking
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.000087+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260428-devnet-service-discovery

## content

Containers on the shared `devnet` Docker network can reach each other by service name. Both `reveal-reveal-app-1` and `cairn-cairn-app-1` successfully reach `cairn-api:8767` using the service name defined in cairn's docker-compose. No IP addresses or host entries are needed.

## resolution

Any new devcontainer that needs cairn access only needs to be on the devnet network and point CAIRN_API_URL to http://cairn-api:8767. No per-container configuration beyond that is required.
