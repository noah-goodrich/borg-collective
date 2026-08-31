# Directive: Rename `project` to `repository` across the code surfaces
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Filed: 2026-08-31*

## Why

The One Front Door plan ratified a vocabulary on 2026-08-24 and then deferred half of it:

- **Repository** — a git repo. What a drone opens on by default. "Currently miscalled `project` throughout the code."
- **Project** — a set of related requirements, PRs and work spanning one or more repositories.

AC7 eliminates the retired word "program" from user-facing surfaces. It explicitly does **not** execute the
repository-side rename, and instead requires that the rename be *filed* as a parented directive. This is that file.

Until it lands, the codebase uses one word for two things. `cmd_program` reads `jq -r '.projects[].path'` from the
registry, where `project` means *repository* — while the same word in the plan's own vocabulary means a cross-repo
workstream. Every new reader has to learn which sense is in play per call site.

## Measured scope

PROJECT_PLAN's Scope Boundaries estimates "~500 occurrences across 57+ files plus the registry schema key and
`.borg-project` markers." Re-measured 2026-08-31 over tracked `*.py` / `*.zsh` / `*.sh` / `*.bats`:

```
git ls-files "*.py" "*.zsh" "*.sh" "*.bats" | xargs grep -oiE "project(s)?" | wc -l   ->  3142
git ls-files "*.py" "*.zsh" "*.sh" "*.bats" | xargs grep -liE "project"    | wc -l   ->    97
```

**3142 occurrences across 97 of 139 tracked code files** — roughly six times the plan's estimate, and it does not
include markdown. Heaviest: `drone.zsh` (307), `tests/cli_contract.bats` (247), `borg.zsh` (232),
`borg_core/link/test_core.py` (85), `borg_core/link/test_shell.py` (80), `borg_core/link/core.py` (77).

Three surfaces are not a sed pass:

1. **The registry schema key.** `~/.config/borg/registry.json` has a top-level `projects` key. Renaming it is a data
   migration on a live file every hook and both CLIs read, with no versioning today.
2. **The `.borg-project` marker.** Written by `drone.zsh` in two places and removed in a third, read by
   `lib/borg-hooks.sh`, and hard-coded into `hooks/bash-guard.sh`'s pre-approved marker-walk string. It also appears
   verbatim in the `borg-link` skill's MARKER-WALK block, which is distributed through the plugin — so the rename
   crosses a repository boundary and a release boundary.
3. **The word is correct in some places.** After the vocabulary split, "project" legitimately means a cross-repo
   workstream. A blind rename would destroy the distinction the rename exists to create. Every site needs a reading.

## The change

Rename the *repository* sense of `project` to `repository`, leaving the *workstream* sense alone. Sequence it so
each step is independently green:

1. **Classify before renaming.** Produce the site inventory: for each of the 97 files, which occurrences mean
   repository and which mean workstream. This is the actual work; the edit is mechanical afterward.
2. **Registry key last, behind a reader that accepts both.** Ship a reader tolerant of `projects` and
   `repositories`, let it run, then migrate the file, then drop the tolerance.
3. **`.borg-project` marker: decide whether to rename it at all.** A marker filename is not a user-facing surface,
   it is on-disk data in every registered repo and inside the distributed plugin. Renaming it needs a migration and
   buys little. Recommend keeping the filename and renaming only the variables that read it — record the decision
   either way.
4. **Tests and goldens move with each step**, never in a trailing commit.

## Acceptance criteria

- [ ] **A site inventory exists** classifying every occurrence as repository-sense or workstream-sense, with the
      workstream-sense sites listed explicitly so a later reader can see they were considered, not missed.
  - Verify: the inventory's total reconciles with the measured 3142, and a spot-check of 20 random sites agrees.
- [ ] **The repository-sense rename lands** across `borg_core/`, `lib/`, `hooks/`, `borg.zsh`, `drone.zsh` and tests.
  - Verify: `make test` at the coverage floor, `make lint` exit 0, `bats tests/` green after each step, not just at
    the end.
- [ ] **The registry migrates without a flag day.** A borg install upgraded mid-session keeps working.
  - Verify: a test that reads a pre-migration registry and a post-migration registry through the same code path.
- [ ] **The `.borg-project` decision is recorded** in CLAUDE.md with its reason, whichever way it goes.
  - Verify: the decision text exists and names the plugin-distribution constraint.
- [ ] **The plugin's MARKER-WALK block and the deployed skill agree with the repo**, since `borg setup` is not the
      only delivery path any more.
  - Verify: the deployed-artifact drift check, or a byte comparison of the two copies.

## Notes

- **This directive is a Step 0.75 blocker by construction, and that is what AC7 asks for.** `borg-assimilate`
  Step 0.75 greps for `^\*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface\*` and refuses to ship
  the parent until every match is shipped or severed. AC7 requires the rename be filed as a parented directive *and*
  not executed, so the two clauses can only both hold if this file is severed — not shipped — when One Front Door
  assimilates, and re-filed as a standalone candidate. Do that deliberately rather than discovering it at ship time.
- Related: the `borg program` verb and the `merge-tree/` occurrences are AC7's own scope, not this directive's. They
  collide though — renaming `borg program` to `borg project` would ship a verb whose name means workstream and whose
  implementation means repository. AC7's naming decision has to land before this directive starts.
- The measured numbers above supersede PROJECT_PLAN's Scope Boundaries estimate. Update that line when this ships.
