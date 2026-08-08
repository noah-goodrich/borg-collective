---
id: obs-20260420-supabase-ipv6-docker-desktop
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- supabase
- docker
- ipv6
- psql
- networking
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.192741+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260420-supabase-ipv6-docker-desktop

## content

Supabase free-tier direct database endpoints are IPv6-only. Docker Desktop containers do not have IPv6 networking by default. Raw psql connections to the cloud DB from inside a devcontainer will fail with connection errors even when credentials are correct.

## resolution

Use the Supabase Supavisor connection pooler endpoint (IPv4-compatible) for any direct DB connections from inside containers, or configure Docker Desktop IPv6 support. The Supabase CLI (HTTPS API) is unaffected and works normally.
