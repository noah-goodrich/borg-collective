# Project Plan: drone compose-lifecycle hooks + Supabase scaffolder + bash-guard
*Established: 2026-04-15*

## Objective

Close three gaps in the drone/borg toolchain that are currently blocking both MVP pivots
(ingle and wallpaper-kit/reveal) and allowing Claude to drift from bash rules:

1. **Add a host-side lifecycle hook mechanism to drone** — `.devcontainer/borg-hooks/pre-up.sh`
   and `post-down.sh` run around `docker compose up/down` so projects can bring outside-compose
   stacks (Supabase local) up and down.
2. **Ship a `drone scaffold --supabase` preset** that generates a standard
   devcontainer + Supabase-joined compose + `supabase init` output, so every Supabase project
   starts from the same template instead of hand-written hooks that drift.
3. **Convert CLAUDE.md's bash rules from advisory to harness-enforced** by extending the
   existing `bash-guard.sh` PreToolUse hook to block bare shell operators, `$()`, and `~`
   paths when they appear outside the allowed escape hatches.

Then backfill ingle and wallpaper-kit to the standard form so all three projects converge.

## Acceptance Criteria

- [ ] **A1.** `drone up ingle` succeeds end-to-end on the host — Supabase stack comes up via
      `pre-up.sh`, external network exists, devcontainer starts.
  - Verify: `drone down ingle; drone up ingle` exits 0; `docker network inspect
    supabase_network_ingle` succeeds.
- [ ] **A2.** `drone restart` invokes `pre-up.sh` on the up-leg but NOT `post-down.sh` on
      the transient down-leg.
  - Verify: bats test in `tests/drone_hooks.bats` asserts pre-up count=1, post-down count=0
    across a restart.
- [ ] **A3.** Projects with no `borg-hooks/` directory work unchanged (no warnings).
  - Verify: existing `cli_smoke.bats` and `lifecycle.bats` green; explicit new test for
    empty-dir case.
- [ ] **A4.** `CLAUDE.md` "Key Patterns" gains a `borg-hooks` entry documenting host-side
      semantics and strict/lenient contract.
  - Verify: `grep -n borg-hooks CLAUDE.md`.
- [ ] **B1.** `drone scaffold --supabase /tmp/scratch-smoke` on an empty dir produces
      working devcontainer + `supabase/config.toml`; `drone up scratch-smoke` succeeds first
      try.
  - Verify: end-to-end host smoke; `docker network inspect supabase_network_scratch-smoke`
    succeeds.
- [ ] **B2.** ingle and wallpaper-kit backfilled from scaffolder templates. Divergences
      limited to documented project-specifics (env vars, ports, python extras).
  - Verify: `diff -r` against reference scaffold output; any remaining diffs are annotated.
- [ ] **B3.** `drone down wallpaper-kit; drone up wallpaper-kit` succeeds against the new
      Supabase-based compose (no more local `reveal-postgres`).
  - Verify: host smoke.
- [ ] **C1.** `bash-guard.sh` blocks the full forbidden-pattern matrix and allows every
      documented escape hatch.
  - Verify: `bats tests/bash_guard.bats`.
- [ ] **C2.** `borg setup` registers bash-guard idempotently in `~/.claude/settings.json`.
  - Verify: `jq '.hooks.PreToolUse' ~/.claude/settings.json` shows it exactly once after
    repeated `borg setup` runs.
- [ ] **C3.** Live: `ls | head` blocked, `bash -c 'ls | head'` works; `find ~/dev` blocked,
      `find /Users/noah/dev` works.
  - Verify: manual smoke in a fresh Claude Code session after install.
- [ ] **Z.** Full `bats tests/` suite stays green.

## Scope Boundaries

- **NOT** `pre-down.sh` / `post-up.sh` — YAGNI.
- **NOT** running hooks inside the container — that's `postCreateCommand`'s job.
- **NOT** a `--force`/`--refresh` mode for the scaffolder (v1 refuses to overwrite existing
  `.devcontainer/`; backfill is diff-and-reconcile).
- **NOT** scaffolding app code (Next.js, etc.). Scaffolder stops at devcontainer +
  `supabase init`.
- **NOT** creating remote Supabase projects.
- **NOT** enforcing `VAR=val cmd` in bash-guard v1.
- **NOT** a full shell parser — heuristic quote-stripping is good enough.
- **If done early:** `--app-type next` scaffolder flag that wraps `create-next-app` +
  baseline Supabase client files.

## Ship Definition

1. All bats green (`bats tests/`).
2. Host smokes pass: `drone up ingle`, `drone scaffold --supabase /tmp/scratch-smoke` +
   `drone up`, `drone up wallpaper-kit` against backfilled compose, bash-guard blocks/allows
   correctly live.
3. `templates/supabase/` + `hooks/bash-guard.sh` committed in borg-collective; backfill
   commits in ingle and wallpaper-kit repos.
4. `CLAUDE.md`, `VERSION` (→ `v0.7.2`), and `Formula/borg-collective.rb` updated.
5. Plan archived to `docs/plans/assimilated/2026-04-15-drone-hooks-supabase-bash-guard.md`.
6. Commits to main in all three repos.

## Timeline

Target: 1 session, ~4h. Breakdown:
- A (lifecycle): 45–60 min
- B (scaffolder + backfill): 90–120 min
- C (bash-guard): 60–90 min
- Ship ceremony: 30 min

Ship-early breakpoint: if hour 4 hits with C incomplete but A+B green, ship A+B as v0.7.2
and file a directive for C as v0.7.3. A is the blocker, B the force-multiplier, C the
polish.

## Risks

1. **`set -e` in drone kills on lenient hook failure.** Write the `post-down.sh exits 1`
   bats test FIRST to lock in the guard.
2. **wallpaper-kit backfill is a migration, not a cleanup.** It currently has its own
   `reveal-postgres` service. If its Supabase work hasn't happened yet, stop and file a
   follow-up rather than forcing the migration in this plan.
3. **`supabase init` on dirty dir.** Detect existing `supabase/` and fail loudly.
4. **bash-guard false positives break flow.** `BORG_BASH_GUARD_SOFT=1` escape valve;
   stay conservative on the heuristic.
5. **`_borg_register_hook` matcher semantics unknown.** Read the function first.
6. **Cold Supabase start is slow (30–90s).** Stream hook stdout so user sees progress.

## Key Files

```
drone.zsh                                      ← add run_borg_hook + cmd_scaffold_supabase
borg.zsh                                       ← register bash-guard in cmd_setup
hooks/bash-guard.sh                            ← NEW: source-of-truth for PreToolUse guard
templates/supabase/                            ← NEW: scaffolder templates
  Dockerfile
  docker-compose.yml.tmpl
  devcontainer.json.tmpl
  borg-hooks/pre-up.sh
  borg-hooks/post-down.sh
tests/drone_hooks.bats                         ← NEW
tests/scaffold_supabase.bats                   ← NEW
tests/bash_guard.bats                          ← NEW
CLAUDE.md                                      ← borg-hooks doc + scaffolder note
VERSION                                        ← bump to v0.7.2
Formula/borg-collective.rb                     ← update for v0.7.2
```

Plus in other repos:
```
ingle/.devcontainer/{docker-compose.yml,devcontainer.json,Dockerfile,borg-hooks/*}    ← backfill
wallpaper-kit/.devcontainer/{...,borg-hooks/*}                                         ← backfill (migration)
```
