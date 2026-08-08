---
id: obs-20260617-item-aliases-rls-intentional
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- ingle
- supabase
- rls
- security
- item-aliases
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.027175+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-item-aliases-rls-intentional

## content

`item_aliases` table in ingle has no RLS — this is intentional. It is a global catalog (shared lookup data, not user-scoped). Enabling bare RLS on it would break functionality.

## resolution

Do not enable RLS on `item_aliases` without first adding an explicit permissive SELECT policy. Document this exception clearly so it is not treated as a security oversight.
