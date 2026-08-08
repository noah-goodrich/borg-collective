---
id: obs-20260617-supabase-cross-project-idp-gated
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- supabase
- auth
- multi-tenant
- enterprise
- pricing
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:01:10.026365+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-supabase-cross-project-idp-gated

## content

Using a Supabase project as a cross-project Identity Provider (SSO/shared auth across multiple Supabase projects) requires Team or Enterprise tier — it is not available on Pro. This eliminates a common multi-app auth consolidation pattern for Pro-tier users.

## resolution

Use schema-per-app within a single Supabase project with shared `auth.users` instead of cross-project IdP federation.
