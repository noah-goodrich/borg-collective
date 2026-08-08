---
id: borg:checkpoint:cairn:20260721-2241-cairn
source: borg
doc_type: checkpoint
project: cairn
slug: 20260721-2241-cairn
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: 9683250cc57f234c1052ae284280589d5e08fd1439518c34615b35996db6e31e
captured_at: '2026-07-21 22:41:32.558328+00:00'
deleted_at: null
created_at: '2026-07-21 22:41:32.559235+00:00'
updated_at: '2026-07-21 22:41:32.559236+00:00'
---

# borg:checkpoint:cairn:20260721-2241-cairn

## body

# Session Checkpoint — 2026-07-21 ~16:15 — cairn — Codex Phase 1a plan locked

## 1. Goal
Begin the Codex (cairn as a versioned belief store): draft the ADR, run the Collective review, then
lock acceptance criteria via /borg-plan — cairn CORE only.

## 2. Accomplished
- Verified prior-session work was already on `docs/codex-adr`: ADR `docs/adr/0001-codex-belief-store.md`
  drafted (`0d4b1c4`) and revised per Collective adversarial review (`fbb587f`) — status Accepted,
  anchors locked (belief = typed VIEW; contradictions always route to human review), 1a/1b phase split.
- Confirmed cairn service healthy (`/health` → 0.5.2; the SessionStart write-failure warning was stale
  from last session, service is up now).
- Ran a fresh Collective review at the **plan/implementation** level (Scope Hawk + Skeptic converged:
  no learned/derived staleness in 1a, contradiction tests on seeded fixtures not the corpus; DB
  Architect + Migration-Safety Engineer: schema-snapshot refresh + downgrade test + keep the belief
  VIEW out of the SQLAlchemy autoload path).
- Locked two design forks (both recommended options): (1) belief VIEW exposes **raw `age_seconds`
  only**, no staleness_score in 1a; (2) **two-PR shape**.
- Wrote `PROJECT_PLAN.md` with 7 locked, verifiable acceptance criteria.

## 3. Ready to Commit
- `PROJECT_PLAN.md` (new, untracked) — ready to commit. No code changed this session, so /simplify is
  not applicable (docs/plan only).

## 4. Blockers
No blockers. Capacity warning noted (4 projects active vs limit 3) — reason this session paused at the
locked-plan gate rather than starting implementation.

## 5. Next Session
Implement **PR-A** (branch off `main`): alembic migration **008** adding `superseded_by` (self-FK,
`ON DELETE SET NULL`) + `source_session` (FK → `sessions.id`) + trigger-maintained `updated_at` to
`patterns` and `observations`; refresh `docs/schema.snapshot.sql` in the SAME commit; add downgrade
test + a `tests/test_migration.py` case asserting the columns + `updated_at` trigger exist. TDD.
Match the `decisions` table's existing FK shape (`docs/schema.snapshot.sql:299-323`). Run inside the
container: `drone exec cairn -- alembic revision -m "..."`, `drone exec cairn -- pytest`. Then PR-B
(belief VIEW + contradiction query + `/belief/*` + review-queue state machine) per PROJECT_PLAN.md.
