---
id: 20260420-supabase-cli-in-base-image
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- supabase
- docker
- devcontainer
- base-image
- cli
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.187857+00:00'
updated_at: '2026-06-16 10:27:02.187858+00:00'
---

# 20260420-supabase-cli-in-base-image

## decision

Install the Supabase CLI directly in Dockerfile.base via GitHub releases rather than as a devcontainer feature or per-project install.

## context

Both ingle and reveal need the Supabase CLI available inside their devcontainers. Keeping it in the shared base image means a single rebuild propagates to all projects.

## reasoning

Centralizing in the base image avoids duplicated install logic across project Dockerfiles and ensures version consistency. The GitHub releases URL pattern (fetch latest Linux binary) keeps the install scriptable without pinning a version manually.
