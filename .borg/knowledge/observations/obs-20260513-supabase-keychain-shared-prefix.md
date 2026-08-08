---
id: obs-20260513-supabase-keychain-shared-prefix
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- supabase
- keychain
- credentials
- naming-convention
- troth
- reveal
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.429217+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260513-supabase-keychain-shared-prefix

## content

Shared Supabase projects use the primary-app prefix for keychain/secret naming. For example, REVEAL_SUPABASE_DB_PASSWORD covers the troth project as well, because troth shares the reveal Supabase instance. Looking for TROTH_SUPABASE_DB_PASSWORD would find nothing.

## resolution

When looking up credentials for a project that shares a Supabase instance with another app, use the primary app's prefix. Captured in reference_supabase_keychain_naming.md in the cross-conversation store.
