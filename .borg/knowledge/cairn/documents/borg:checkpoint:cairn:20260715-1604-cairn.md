---
id: borg:checkpoint:cairn:20260715-1604-cairn
source: borg
doc_type: checkpoint
project: cairn
slug: 20260715-1604-cairn
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: ff52a13a715b6080050e3d03c0f439c206a142522799a0cde493c79b0847f4a5
captured_at: '2026-07-15 16:04:29.340880+00:00'
deleted_at: null
created_at: '2026-07-15 16:04:29.344371+00:00'
updated_at: '2026-07-15 16:04:29.344375+00:00'
---

# borg:checkpoint:cairn:20260715-1604-cairn

## body

# Session Checkpoint — 2026-07-15 ~09:40 — cairn drone — COMPLETE

The 2026-07-14 mining sprint (#30/#31/#32) + source_session backfill is fully shipped, run, and deployed.
Supersedes the 2026-07-15-0100 "blocked on Docker" checkpoint.

## Shipped + live (cairn 0.5.2)

- **#33 closes #30** — source_session attribution (service/CLI/REST/MCP + `CAIRN_SESSION_ID` env + FK-stub
  guard) and edge-writers: `superseded_by` (record_decision supersedes=), `times_applied` (mark_pattern_applied
  + positive-feedback bump), `decision_context` (depends_on="type:ref").
- **#34 closes #31** — reuse rollup (`cairn reuse-stats`, `GET /stats/reuse`) + top_ids null-guard. (Reframe:
  top_ids was never missing — the "97%" was zero-hit searches + already-fixed null ids.)
- **#35 closes #32** — token_spend per-session-peak dedup. `/stats/usage` total $62,778.89 → $46,091.79.
- **#36 refs #30** — `backfill-source-session` command.
- **#37** — release: bump to 0.5.2. Tag `v0.5.2` pushed.

## Backfill — RUN against prod (idempotent, dry-run-verified first)

`cairn backfill-source-session --commit` (full ~82%, no gap cap): decisions **971**, patterns **606**,
observations **1468** attributed → 81/83/83% filled, **0 dangling FKs**, attributed session's project matches
each record's. Re-running now updates 0.

## Deploy — cairn-api at 0.5.2, verified live

Local `docker compose --project-name cairn build cairn-api && up -d` (GHCR was stale at 0.4.0 — 0.5.0/0.5.1 were
never tag-published). Post-deploy: `/health` **0.5.2**, `/ready` **200** (migrations 006 head, model loaded),
`/stats/reuse` returns data (was 404), `/stats/usage` total **$46,091.79**. GHCR publish of `v0.5.2` (arm64,
tags 0.5.2/0.5/latest) **completed success** — registry now current for other devcontainers.

## Nothing outstanding for cairn

Working tree clean on `main`. Full suite 486 passed. All four issues (#30/#31/#32) closed; graph is populated
and traversable on the existing Postgres.

## Optional future follow-ups (noted in PRs, deliberately NOT built)

- Per-tag reuse rollup + a lightweight "acted-on" (vs mere-retrieval) signal (#31 optional asks).
- Run-aware spend dedup for the 2 session-id-reuse reset sessions (#32, +$615 / 1.3%).
- LLM re-mining pass to *infer* superseded_by / decision_context edges (the only way to "recover" the 3
  non-attribution edges, which were never captured). Would produce inferred, clearly-labeled edges.

## Infra note

Docker Desktop hung host-wide overnight (recurring — also in the 2026-07-14 handover); a quit/reopen restart
didn't stabilize it that night but it was healthy by morning. Background `drone exec` does NOT flush output —
run drone commands in the foreground.
