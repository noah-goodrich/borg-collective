---
id: borg:checkpoint:borg-collective:20260801-0300-borg-collective
source: borg
doc_type: checkpoint
project: borg-collective
slug: 20260801-0300-borg-collective
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: f864169f02e681dc3dd6bf359cc00144e48ca166ba17c75e2cc4387e6f825bcb
captured_at: '2026-08-01 03:00:50.308369+00:00'
deleted_at: null
created_at: '2026-08-01 03:00:50.310386+00:00'
updated_at: '2026-08-01 03:00:50.310390+00:00'
---

# borg:checkpoint:borg-collective:20260801-0300-borg-collective

## body

## 1. Goal
Sync every borg-collective doc to the current v0.8.9 code, and run a competitive research refresh comparing borg
against `i-have-adhd` and the 2026-Q3 landscape (build-vs-lean-on).

## 2. Accomplished
_(Unchanged since the 2026-07-31-2044 checkpoint — no new work this interval; this is the post-cutover snapshot.)_
- **Docs sync shipped → PR #109** (`docs/sync-v0.8.9`, 14 files, +649/-95): phantom commands fixed, full
  hooks/lib/skills/agents/launchd inventories, new Usage Guardian + Recon + Agent-Roster + Presence subsections.
- **Model routing cohered:** `agents/ROUTING.md` now matches `settings.json` — Opus 4.8 default, Fable 5 opt-in.
- **`borg.zsh`** `BORG_VERSION` v0.8.0 -> v0.8.9; **plan hygiene** recon-fanout (#108) + wip-reconciliation (#62) ->
  `assimilated/`; **`PROJECT_PLAN.md`** written (7 criteria, all met).
- **Research:** `docs/research/2026-07-30-competitive-refresh/analysis.md` (blind-reviewed REVISE, incorporated).
- **4 audit errors caught against code** (presence real, six-pager exists, drone feature/toggle/fix, postCreate lesson).

## 3. Ready to Commit
Nothing pending — PR #109 committed and pushed. Intentionally uncommitted: `PROJECT_PLAN.md`,
`.borg/research/i-have-adhd-2026-07-30.md`, prior `.borg/checkpoints/*`. `/simplify` not needed (only the one-line
`BORG_VERSION` change is non-doc).

## 4. Blockers
No blockers. PR #109 awaits review/merge. Three follow-ups scoped but unstarted — none authorized.

## 5. Next Session
1. **Land PR #109** — review/merge (optionally `/borg-verify`); after merge, `/borg-assimilate` moves
   `PROJECT_PLAN.md` -> `docs/plans/assimilated/`.
2. **Plugin-parity check** — do `CLAUDE.md`/`agents/ROUTING.md`/`borg.zsh` ship in the `claude-plugins` bundle? Rebuild
   if so.
3. **Pick one strategic follow-up:** (a) fan-out validation spike (native background-agents + `isolation:worktree` in a
   non-git-repo CWD), (b) extract `adhd-guardrails` into a forkable one-file skill, (c) recon contradiction prove-or-drop
   (#46) before evaluating Graphiti.
