# Directive: WIP Reconciliation → Clean, Pushed Baseline (borg-collective, 2026-07-08)

**Owner:** borg-collective session · **Requested by:** orchestrator (Noah-approved 2026-07-08 — he chose "route to the
borg-collective session" over having the orchestrator do it).

## Why

Noah is updating his work machine and needs `borg-collective` fully committed + pushed so the work machine can pull it.
This repo has stuck local work and a diverged branch that must be reconciled first. This is the front gate for the sync.

## Current state (inspected from the orchestrator host, 2026-07-08 — verify fresh before acting)

- On branch **`chore/remove-homebrew-artifacts`** (NOT `main`).
- **1 unpushed commit** + **10 uncommitted files** (`.borg/` checkpoints, `skills/fable-reviewer/` **source**,
  `docs/orchestration-architecture.md`, and others).
- Branch is **4 behind its origin** (diverged → a plain push will be rejected; needs a rebase or merge first).

## The ONE deliverable

A clean, pushed baseline on `chore/remove-homebrew-artifacts`: clean `git status`, local branch in sync with origin, so
`git -C ~/dev/borg-collective ... pull` on the work machine gets everything. Nothing else.

## Do

1. **Inventory** the 10 uncommitted files + the 1 unpushed commit. Classify and **commit coherently** — group by concern
   (e.g. `skills/fable-reviewer/` source, `docs/orchestration-architecture.md`, `.borg/` checkpoints). Exclude junk /
   build artifacts / any `*.bak`.
2. **Resolve the divergence:** `git fetch`, then rebase your local commits onto `origin/chore/remove-homebrew-artifacts`
   (4 behind) — resolve any conflicts. Prefer rebase for a linear history; a merge is acceptable if conflicts are hairy.
3. **Push.** Confirm clean `git status` and the branch is in sync with origin.
4. **Decide `main`:** if `chore/remove-homebrew-artifacts`'s work is complete, open/merge it to `main`; otherwise leave
   it pushed for the sync and note what remains before it can merge.

## Constraints (hard)

- **LOCAL only — NO GitHub Actions** (per the current standard: we moved off GHA to local deploys to avoid the tax).
- No force-push over shared history without explicitly flagging it in your report.

## Note

The `fable-reviewer` skill's **mirror** was already committed to `claude-plugins` (commit `d346a51`) per the
source-of-truth split (borg-collective repo = source; `claude-plugins/borg-collective/` = synced mirror). This repo holds
the **source** — make sure the two match after you commit.

## Return

Report: final clean+pushed state (branch in sync with origin), whether it merged to `main`, and any conflicts/surprises.
