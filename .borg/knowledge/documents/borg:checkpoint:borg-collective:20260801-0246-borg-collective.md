---
id: borg:checkpoint:borg-collective:20260801-0246-borg-collective
source: borg
doc_type: checkpoint
project: borg-collective
slug: 20260801-0246-borg-collective
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: 681dea4de8c9366cf016c70095ed13693d55216dde5dbb3e31aae5ab45c9bc1b
captured_at: '2026-08-01 02:46:55.824938+00:00'
deleted_at: null
created_at: '2026-08-01 02:46:55.826770+00:00'
updated_at: '2026-08-01 02:46:55.826771+00:00'
---

# borg:checkpoint:borg-collective:20260801-0246-borg-collective

## body

## 1. Goal
Sync every borg-collective doc to the current v0.8.9 code, and run a competitive research refresh comparing borg
against `i-have-adhd` and the 2026-Q3 landscape (build-vs-lean-on).

## 2. Accomplished
- **Docs sync shipped → PR #109** (`docs/sync-v0.8.9`, 14 files, +649/−95). Fixed phantom commands
  (`/borg-ship`→`/borg-assimilate`, `drone start`→`drone feature`), completed all file inventories
  (hooks 12 / lib 14 / skills 17 / agents 6 / launchd 4), added Usage Guardian + Recon + Agent-Roster +
  Presence subsections to `architecture.md`.
- **Model routing cohered:** `agents/ROUTING.md` now agrees with `settings.json` — Opus 4.8 is the session default,
  Fable 5 is opt-in. No code/settings change; specialist frontmatter untouched.
- **`borg.zsh`:** `BORG_VERSION` v0.8.0 → v0.8.9 (authoritative `VERSION` file + latest tag).
- **Plan hygiene:** recon-fanout (#108) + wip-reconciliation (#62 merged) → `docs/plans/assimilated/`.
- **`PROJECT_PLAN.md`** written (docs-sync plan, 7 acceptance criteria, all met).
- **Research deliverable:** `docs/research/2026-07-30-competitive-refresh/analysis.md` (in the PR), blind-reviewed
  (verdict REVISE, incorporated). Raw track files: `.borg/research/i-have-adhd-2026-07-30.md` + scratchpad landscape.
- **4 audit errors caught by verifying against code** (not applied blindly): presence IS implemented; `six-pager.md`
  exists; `drone feature`/`toggle`/`fix` descriptions were wrong guesses; CLAUDE.md's "drone never runs
  postCreateCommand" Learned lesson was stale (drone runs both, postCreate sentinel-guarded).

## 3. Ready to Commit
Nothing pending — PR #109 is already committed and pushed. Intentionally left **uncommitted**: `PROJECT_PLAN.md`
(active plan, archived on assimilate), `.borg/research/i-have-adhd-2026-07-30.md`, and pre-existing
`.borg/checkpoints/2026-07-25-1055.md`. `/simplify` not run and not needed — the only non-doc change is the one-line
`BORG_VERSION` bump; no code logic, reuse, or dead-code surface for it to act on.

## 4. Blockers
No blockers. PR #109 awaits Noah's review/merge. Three strategic follow-ups are scoped but unstarted, awaiting
Noah's pick (see Next Session) — none authorized yet.

## 5. Next Session
1. **Land PR #109** — review/merge (optionally run `/borg-verify` first). After merge, run `/borg-assimilate` to move
   `PROJECT_PLAN.md` → `docs/plans/assimilated/`.
2. **Plugin-parity check** — confirm whether `CLAUDE.md` / `agents/ROUTING.md` / `borg.zsh` ship inside the
   `claude-plugins` bundle; if so, rebuild the plugin so the synced docs propagate.
3. **Pick one strategic follow-up** (leverage order): (a) **fan-out validation spike** — test native background-agents +
   `isolation:worktree` against the not-a-git-repo CWD case that forced custom nanoprobe worktrees; the one experiment
   that could retire custom code. (b) **Extract `adhd-guardrails`** into a one-file forkable installable skill (the
   i-have-adhd distribution pattern) — the growth move. (c) **Recon contradiction prove-or-drop** — let #46 run, gather
   evidence of real deficiency before evaluating Graphiti (do NOT replace just-shipped code speculatively).
