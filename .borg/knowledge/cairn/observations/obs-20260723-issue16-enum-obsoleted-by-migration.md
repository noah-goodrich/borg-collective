---
id: obs-20260723-issue16-enum-obsoleted-by-migration
session_date: '2026-07-24'
project: cairn
tool: claude-code
tags:
- observations
- category
- enum
- migration
- issue-hygiene
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 03:54:03.159400+00:00'
updated_at: '2026-07-24 03:55:24.084484+00:00'
---

# obs-20260723-issue16-enum-obsoleted-by-migration

## content

Issue #16 (record_observation 500 on invalid category) was opened when `category` was an enum column. Migration 007 changed category to free-form text, eliminating the invalid-enum error path entirely. The issue remained open and stale.

## resolution

Confirm migration 007 is live in prod, then close issue #16 as obsolete. No code fix needed — the schema change resolved it.
