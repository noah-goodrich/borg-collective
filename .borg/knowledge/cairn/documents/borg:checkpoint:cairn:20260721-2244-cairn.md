---
id: borg:checkpoint:cairn:20260721-2244-cairn
source: borg
doc_type: checkpoint
project: cairn
slug: 20260721-2244-cairn
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: e7a31e11f9f3690710723acf5294b35155db33f0f57903827d12c0ea522a6f17
captured_at: '2026-07-21 22:44:14.870778+00:00'
deleted_at: null
created_at: '2026-07-21 22:44:14.871958+00:00'
updated_at: '2026-07-21 22:44:14.871961+00:00'
---

# borg:checkpoint:cairn:20260721-2244-cairn

## body

# Session Checkpoint — 2026-07-21 ~17:10 — cairn — Codex Phase 1a: ADR + PR-A shipped to main

## 1. Goal
Begin the Codex (cairn as a versioned belief store): draft ADR, Collective-review, lock a plan, and
land Phase 1a foundation — cairn CORE only.

## 2. Accomplished
- **ADR merged (#39):** `docs/adr/0001-codex-belief-store.md` (Accepted, Collective-reviewed) +
  `PROJECT_PLAN.md` (locked Phase 1a acceptance criteria) now on `main`.
- **PR-A merged (#40):** belief-lineage migration 008 (additive) on `main`:
  - `patterns.superseded_by` (self-FK → patterns.id), `observations.superseded_by` (→ observations.id),
    `observations.updated_at` (timestamptz DEFAULT now() NOT NULL).
  - `set_updated_at()` trigger fn + BEFORE UPDATE triggers on **decisions, patterns, observations**
    (decisions had the column but no trigger; the belief VIEW reads age from all three atoms).
  - ORM synced (models_db.py); `docs/schema.snapshot.sql` regenerated; downgrade tested.
  - source_session already existed on all three (PR #33) — untouched.
- **Verification:** full suite 497 pass, lint clean, CI green (Fitness + Test-suite/drift-check),
  independent `/borg-verify` reviewer PASS (re-ran 42 + 497, 0 findings, 0 scope violations).
- **Snapshot-regen unblocked:** discovered dev-postgres is now pg17 with pg_dump that matches CI's
  pg16 snapshot byte-for-byte (empty baseline diff). Updated memory `project_schema_snapshot_driftcheck`
  with the clean regen recipe (was "no pg_dump in container — patch CI's diff", now stale).

## 3. Ready to Commit
Nothing pending — all work merged to `main`; local `main` synced; working tree clean.

## 4. Blockers
No blockers. Capacity warning still active (4 projects vs limit 3).

## 5. Next Session
**PR-B (Codex Phase 1a, second half)** per `PROJECT_PLAN.md`:
- Belief typed-VIEW: 3-way UNION over decisions ∪ patterns ∪ observations mirroring
  `search_knowledge()`'s column contract; expose `scope, claim, status, superseded_by,
  source_session, updated_at, age_seconds (EXTRACT(EPOCH FROM (now()-updated_at)))`. **No
  staleness_score** (gated to 1b). Expose via raw SQL in `service.py` — keep it OUT of the
  SQLAlchemy autoload path (migration-ordering safety). For patterns/observations, derive `status`
  in the VIEW from `superseded_by IS NOT NULL` (they have no status column; decisions does).
- Contradiction query (fixture-verified: seeded conflicting pair flagged, reinforcing pair not;
  threshold = config value).
- `/belief/*` + review-queue write endpoint with persisted `proposed → superseded|invalidated|
  dismissed` state machine (dismissed terminal + persisted, does not re-fire); persist the
  candidate snapshot (conflicting row id, similarity-at-detection, triggering feedback signal).
- **Prod deploy of migration 008:** the shared cairn-api (0.5.2) DB does NOT yet have 008 applied.
  It's additive + safe for the deployed image (raw-SQL reads, explicit-column inserts), but apply
  it (`alembic upgrade head` against shared cairn DB, or redeploy cairn-api) BEFORE PR-B's read
  layer goes live — deliberately NOT done this session (unprompted prod migration at a pause).
