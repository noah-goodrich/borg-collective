---
id: borg:checkpoint:borg-collective:20260725-1655-borg-collective
source: borg
doc_type: checkpoint
project: borg-collective
slug: 20260725-1655-borg-collective
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: 632d9c43b6881304b6354a56dfa3a194247e8d0910b411dc6025943fdfa39a4c
captured_at: '2026-07-25 16:55:53.404138+00:00'
deleted_at: null
created_at: '2026-07-25 16:55:53.405287+00:00'
updated_at: '2026-07-25 16:55:53.405288+00:00'
---

# borg:checkpoint:borg-collective:20260725-1655-borg-collective

## body

## 1. Goal
Close the Usage Guardian directive's data-independent Phase-2 work by building the >=92% dispatch hard-stop veto hook
(after the 85% checkpoint-sweep), default-OFF and fail-OPEN.

## 2. Accomplished
- **>=92% dispatch hard-stop veto — built, verified, merged (PR #89, `9b9c219` on `main`).** `hooks/borg-dispatch-guard.sh`,
  a `PreToolUse` hook (matcher `Agent|Workflow`) that denies new nanoprobe/workflow dispatch (exit 2) only when armed +
  the latest `usage-samples.jsonl` row is a fresh `ok` reading >= `BORG_USAGE_HALT_PCT`. Reads the existing samples file
  (no poller change); **fail-OPEN** on every uncertainty; **default-OFF** (`BORG_USAGE_HALT_ENABLED`). Wired into
  `build-plugin.sh` (hooks.json `Agent|Workflow` entry + build-list copy), both asserted by a source-parity test.
  18 new bats, `usage_watch` 34/34 unchanged, shellcheck clean, borg-verify PASS (fail-open contract independently
  confirmed airtight).
- **85% checkpoint-sweep** (PR #88, earlier this session) also merged — both guardian halves now on `main`, default-OFF.
- Both completed plans assimilated -> `docs/plans/assimilated/`; directive updated with dated result sections.

## 3. Ready to Commit
Nothing — working tree clean, local now synced to `origin/main` (HEAD `e3479e1`). `/simplify` was run on both builds
(no fixes needed). All session checkpoints retained on `main`.

## 4. Blockers
No blockers on the code. Two **housekeeping anomalies** surfaced by the live read (not blockers, but need action):
- **Duplicate PR #90 is OPEN** on branch `feat/usage-guardian-dispatch-guard` — same branch/title as the already-MERGED
  #89. Its content is already on `main` (via #89's squash). It is cruft and should be **closed** (and the stale branch
  deleted).
- Local checkout was stale (sitting on the merged feature branch); now fixed — synced to `main`.

## 5. Next Session
Both guardian halves (85% sweep + >=92% dispatch-guard) are **built, merged, shipping default-OFF**. Two things:
1. **Cleanup (quick):** close duplicate PR #90 and delete its branch —
   `gh pr close 90 --repo noah-goodrich/borg-collective --delete-branch`.
2. **The one remaining directive item — live-cap validation (not code; needs a real near-cap session).** Arm both
   halves (`BORG_USAGE_SWEEP_ENABLED=1` + `BORG_USAGE_HALT_ENABLED=1`, via env or the usage-watch plist's
   `EnvironmentVariables`), then confirm end-to-end near a genuine cap: the sweep delivers `/borg-link-up` to active
   drone panes, AND a dispatch attempt at >=92% is actually blocked by the hook's exit 2 (bats only proves the hook
   *emits* exit 2 — not that Claude Code honors it). If both hold, keep armed and let threshold data accrue (85% still
   rests on ONE near-cap episode — do not tune until 3+). Then the directive
   (`docs/plans/directives/2026-07-08-usage-guardian-build.md`) can be assimilated/closed.
   Entry points: `bin/borg-usage-watch` (`_run_sweep`), `hooks/borg-dispatch-guard.sh`.
