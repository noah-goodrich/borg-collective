---
id: borg:checkpoint:cairn:20260724-0514-cairn
source: borg
doc_type: checkpoint
project: cairn
slug: 20260724-0514-cairn
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: 937cb79ddd0d4beda4ebe37db9d60d0ac2cd6c6073d7a004a4deaa3f564e268f
captured_at: '2026-07-24 05:14:50.753412+00:00'
deleted_at: null
created_at: '2026-07-24 05:14:50.754634+00:00'
updated_at: '2026-07-24 05:14:50.754635+00:00'
---

# borg:checkpoint:cairn:20260724-0514-cairn

## body

# Session Checkpoint — 2026-07-23 ~23:14 — cairn — Codex Phase 1a SHIPPED

## 1. Goal
Finish everything remaining in the Codex Phase 1a project plan (cairn CORE belief store) so it could
be assimilated.

## 2. Accomplished
Phase 1a is **fully shipped and assimilated**.
- **Housekeeping:** closed obsolete issue #16 (migration 007 made `category` free-form); applied
  migration **008** to shared prod cairn (was at 007).
- **PR-B (#41, merged):** migration **009** — the `belief` typed-VIEW (real `CREATE VIEW`, raw-SQL
  queried in `service.py`, **not ORM-mapped**; `age_seconds = GREATEST(0, EXTRACT(...))` clamped for
  clock skew; no `staleness_score`) + `contradiction_review` table (state machine
  `proposed→superseded|invalidated|dismissed`, `dismissed` terminal; `UNIQUE(belief_id,conflicting_id)`
  + `ON CONFLICT DO NOTHING` → dismissed never re-surfaces). Config-driven detection
  (`CAIRN_CONTRADICTION_SIMILARITY_THRESHOLD`, default 0.85).
  `service.beliefs/detect_contradictions/contradiction_queue/resolve_contradiction` + REST `/belief/*`
  + MCP tools. New tests `test_belief_view.py`, `test_belief_contradiction.py`, migration-009 class.
  **519 pass**, lint clean, **borg-verify PASS**, CI green (incl. schema drift-check via a
  pg16-throwaway snapshot).
- **Release 0.5.3 (#42, merged; tag `v0.5.3`):** version bump; migration 009 applied to prod
  (007→009); `cairn-api` container **redeployed on 0.5.3** — verified live at :8767 (`/health`→0.5.3,
  `/ready` migrations match, `/belief` + `/belief/contradictions/*` serving real prod data).
- **Assimilated:** `PROJECT_PLAN.md` → `docs/plans/assimilated/2026-07-21-codex-phase-1a-cairn-core-belief-store.md`
  with ship line + Additional Work section. Updated cairn memory `project_codex_belief_store`.

## 3. Ready to Commit
Nothing — working tree is clean, `main` is in sync with origin (HEAD `6c8489c` assimilate commit).
`/simplify` was run this session before the PR-B commit (removed an unused constant + an awkward test
assert).

## 4. Blockers
No blockers. One async item in flight: the `v0.5.3` tag triggered `publish-image.yml` (was
`in_progress` at checkpoint) to publish `ghcr.io/noah-goodrich/cairn:0.5.3` for **other** hosts — the
local machine was already redeployed from a local build, so nothing here depends on it.

## 5. Next Session
Phase 1a is closed — do **not** reopen it. Options for next:
- **Verify the GHCR publish** succeeded: `gh run list --workflow=publish-image.yml --limit 1` — should
  show `v0.5.3` completed. Only matters when another host/devcontainer pulls the image.
- **Phase 1b is GATED** — the learned per-scope staleness clock. Do not start until the corpus has ≥N
  real supersession events (currently ~0; `superseded_by` is near-100% NULL). Check with a query on
  `contradiction_review` resolutions + `superseded_by` counts before considering it.
- **Phase 2 (borg-collective wiring)** is the more likely next move: checkpoint-write hook populating
  contradiction candidates, `SessionStart` scoped-prior injection (reads the `belief` VIEW), and a
  review-queue CLI/UI + a `borg doctor` "N contradictions pending > X days" health check. Entry
  points: `service.detect_contradictions` / `contradiction_queue` (cairn side) and the borg hook
  layer (borg-collective repo).
- Capacity note: the session opened with a 4-projects-vs-3 warning — run `borg-next` before starting
  new work.
