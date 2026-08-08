---
id: 20260617-troth-migration-no-op-placeholders
date: '2026-06-17'
project: borg-collective
domain: infrastructure
tags:
- supabase
- migrations
- troth
- reveal
- shared-ledger
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-17 18:01:10.021476+00:00'
updated_at: '2026-06-17 18:01:10.021477+00:00'
---

# 20260617-troth-migration-no-op-placeholders

## decision

Add no-op placeholder migrations in troth to unblock `db push` when the shared ledger has migrations from other apps (reveal) that troth doesn't own.

## context

troth's `db push` was blocked because reveal's newest shared-ledger migrations were present in the DB but not in troth's migration directory.

## reasoning

No-op placeholders let Supabase CLI consider the ledger 'up to date' without troth needing to own or duplicate reveal's migration content. Minimal-footprint fix that unblocks deployment without architectural side effects.
