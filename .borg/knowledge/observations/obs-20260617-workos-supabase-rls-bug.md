---
id: obs-20260617-workos-supabase-rls-bug
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- supabase
- workos
- rls
- auth
- open-bug
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.026772+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-workos-supabase-rls-bug

## content

WorkOS as an external IdP for Supabase has a known open bug (supabase/auth#2476) that breaks RLS — JWT claims from WorkOS are not correctly propagated into Supabase's RLS evaluation context.

## resolution

Do not use WorkOS↔Supabase RLS until supabase/auth#2476 is resolved. Track the issue before adopting this pattern.
