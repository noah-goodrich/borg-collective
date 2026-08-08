---
id: borg:checkpoint:cairn:20260730-2323-cairn
source: borg
doc_type: checkpoint
project: cairn
slug: 20260730-2323-cairn
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: a1575b6ef92534e12b2225b25eed28f4e6e2bb36acb76f46ffd0bd27329c925e
captured_at: '2026-07-30 23:23:00.841317+00:00'
deleted_at: null
created_at: '2026-07-30 23:23:00.843267+00:00'
updated_at: '2026-07-30 23:23:00.843269+00:00'
---

# borg:checkpoint:cairn:20260730-2323-cairn

## body

# Session Checkpoint — 2026-07-30 17:22 — cairn — #46 WS1 shipped

## 1. Goal
Resolve the remaining scope of issue #46 — starting from three open design questions — and ship the
high-value piece: attribute + belief-integrate the `backfill-commit` mining path.

## 2. Accomplished
- **Design decisions locked** (via discussion): #46's three open questions collapsed to two workstreams.
  WS1 = route mining through `service.*` (real value). WS2 = a narrow explicit "persist arbitrary fact"
  valve — **deferred** (lives in borg-collective recon, gated on real frequency data, two anecdotes don't
  justify it). Interactive-session non-recording judged by-design.
- **Corrected a false premise mid-flight:** `service.record_*` does **not** run contradiction detection
  inline (it's a decoupled on-demand pass), so rerouting adds no per-row similarity query — only inline
  embedding, which replaces the old `re-embed` step.
- **Shipped WS1 (PR #54, merged `edfd93a`):** `cairn backfill-commit` now fans mined candidates into
  `service.record_batch` (one batch per YAML file) instead of bare `db.insert_*`. New helpers in
  `src/cairn/cli.py`: `_yaml_date`, `_backfill_items`, `_commit_candidate_file`. Mined rows are now
  embedded + call-logged on write; decisions carry `source_tool="cairn-backfill-commit"`; rows are
  belief/contradiction-visible; the manual `re-embed` post-step is deleted.
- **Tests:** rewrote the mock-based commit test as a DB-free wiring test + added
  `tests/test_backfill.py::TestBackfillCommitRealDB` (real-DB tier: asserts embedding non-NULL,
  `source_tool`, `call_log` entry, row-count parity, and a mined row landing in `contradiction_review`).
  **527 → 529 pytest**, ruff/mypy/sqlfluff clean.
- **Gated ship:** `/simplify` (clean), Collective Review (ship), **borg-verify PASS** (both new real-DB
  tests confirmed executing, not skipped) before merge.
- **Assimilated:** plan archived to `docs/plans/assimilated/2026-07-30-cairn-mining-write-path-through-service.md`
  (`64711ce`); issue #46 commented + kept OPEN for WS2 + interactive-session confirmation; memory
  `project_cairn_write_path_reality` updated.

## 3. Ready to Commit
Nothing — working tree clean, `main` in sync with origin (HEAD `64711ce`). `/simplify` already run this
session on the changed files (`src/cairn/cli.py`, `tests/test_backfill.py`); reported clean, no edits.

## 4. Blockers
No blockers.

## 5. Next Session
WS1 is closed — do not reopen. Options, in rough priority:
- **WS2 instrumentation (borg-collective, not cairn):** before building the "persist arbitrary fact"
  valve, add a counter/log in the recon fan-out for reconciled facts it could NOT persist
  (non-contradiction facts). Let real frequency justify the valve. Entry point: borg-collective recon
  `_recon_persist_contradictions` seam. The cairn side (`POST /record/batch`) already exists.
- **#46 gap 3:** confirm interactive-session non-recording (0 of last 7d's 380 sessions self-recorded) is
  by-design → close as not-a-gap or split into its own design issue.
- **#49:** blessed non-interactive `bin/cairn-up` bring-up entry point so `borg init` can auto-recover
  cairn (companion: borg-collective #103) — small, well-scoped.
- Carry-forward nit (non-blocking): `_commit_candidate_file`'s `zip(items, result["results"])` assumes
  `record_batch` preserves item order — documented + test-covered, but would miscount silently if
  `record_batch` ever reorders.
- Capacity: session opened flagging 5 projects active/waiting vs limit 3 — run `borg next` before new work.
