---
id: 20260616-compose-pin-to-versioned-tag
date: '2026-06-16'
project: cairn
domain: infrastructure
tags:
- cairn
- docker-compose
- pinning
- deployment
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:02.540973+00:00'
updated_at: '2026-06-16 10:27:02.540973+00:00'
---

# 20260616-compose-pin-to-versioned-tag

## decision

compose.yml pinned from :latest to :0.2.0 after validated deployment.

## context

After successfully deploying and verifying cairn 0.2.0 (health check, migrations, data integrity), the compose.yml was updated to pin the exact version.

## reasoning

Pinning ensures reproducible deployments and makes rollback trivial (known digest sha256:4565aede...). :latest is a moving target that can pull in untested changes.
