---
id: obs-20260504-multi-site-port-strategy
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- devcontainer
- ports
- multi-site
- docker
- astro
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.386594+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260504-multi-site-port-strategy

## content

When running multiple Astro devcontainers on the same host, each must use a unique host port. The de-facto pattern in this project is to increment from 4321: reveal-site uses 4321, ingle-site uses 4322. Future sites should continue incrementing.

## resolution

Document the port registry (or use borg registration) so new sites can look up the next available port without collisions.
