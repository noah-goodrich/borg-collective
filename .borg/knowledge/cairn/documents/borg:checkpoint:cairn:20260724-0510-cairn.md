---
id: borg:checkpoint:cairn:20260724-0510-cairn
source: borg
doc_type: checkpoint
project: cairn
slug: 20260724-0510-cairn
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: cf6623c73f1fff5131b05762d3e90dc013d854605700a263e5ed6574f2bfced4
captured_at: '2026-07-24 05:10:29.184617+00:00'
deleted_at: null
created_at: '2026-07-24 05:10:29.186000+00:00'
updated_at: '2026-07-24 05:10:29.186002+00:00'
---

# borg:checkpoint:cairn:20260724-0510-cairn

## body

# Session Checkpoint — 2026-07-23 ~21:50 — cairn — Codex Phase 1a status check

## 1. Goal
Begin the Codex (cairn → versioned belief store): ship the Phase 1a foundation (cairn CORE only),
then report status and open items.

## 2. Accomplished
Phase 1a first half is shipped to `main` (done 2026-07-21, verified live today):
- **ADR merged (#39):** `docs/adr/0001-codex-belief-store.md` (Accepted, Collective-reviewed) +
  `PROJECT_PLAN.md` (locked acceptance criteria).
- **PR-A merged (#40):** additive migration 008 — `patterns.superseded_by` + `observations.superseded_by`
  self-FKs, `observations.updated_at`, and a `set_updated_at()` trigger maintaining `updated_at` on all
  three belief atoms (decisions/patterns/observations). ORM synced, schema snapshot regenerated,
  downgrade tested. CI green, independent `/borg-verify` PASS (re-ran 42 + 497 tests, 0 findings).
Today: live-read status only (no new code) — confirmed the deploy gap and a stale issue (see below).

## 3. Ready to Commit
Nothing changed this session — working tree clean on `main`, in sync with origin. No `/simplify`
needed. (Two OPTIONAL housekeeping edits identified but NOT made: tick the 4 completed PR-A checkboxes
in `PROJECT_PLAN.md`; close obsolete issue #16.)

## 4. Blockers
No blockers. Capacity warning (4 projects vs limit 3) was active at session start — orchestrator-level,
verify with `borg-next` before starting PR-B.

## 5. Next Session
Two quick housekeeping items, then PR-B:
- **Apply migration 008 to shared prod cairn DB** (live read: prod is at `007`, image `0.5.2`; 008 not
  deployed). Additive + safe for the running image: `drone exec cairn -- env POSTGRES_DB=cairn alembic
  upgrade head`. Must land before PR-B's read layer goes live.
- **Close issue #16** (record_observation 500 on invalid category) if confirmed obsolete — migration 007
  made `category` free-form, so the "invalid enum" scenario no longer exists.
- **Tick PR-A checkboxes** in `PROJECT_PLAN.md` (criteria 1-3 + nothing-breaks are met).
Then **PR-B (Codex Phase 1a, second half)** per `PROJECT_PLAN.md`:
- Belief typed-VIEW: 3-way UNION over decisions ∪ patterns ∪ observations mirroring `search_knowledge()`'s
  column contract; expose `scope, claim, status, superseded_by, source_session, updated_at, age_seconds
  (EXTRACT(EPOCH FROM (now()-updated_at)))`. **No staleness_score** (gated to 1b). Raw SQL in `service.py`,
  kept OUT of the SQLAlchemy autoload path. Derive `status` from `superseded_by IS NOT NULL` for
  patterns/observations (they have no status column; decisions does).
- Fixture-verified contradiction query (seeded conflicting pair flagged; reinforcing pair not; threshold
  = config value).
- `/belief/*` + review-queue write endpoint with persisted `proposed → superseded|invalidated|dismissed`
  state machine (dismissed terminal + persisted; persist candidate snapshot: conflicting row id,
  similarity-at-detection, triggering feedback signal). TDD.
