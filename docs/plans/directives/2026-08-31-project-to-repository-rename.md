# Directive: Rename `project` to `repository` across the code surfaces
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface (assimilated 2026-09-23)*
*Filed: 2026-08-31*

## Vocabulary, clarified by Noah on 2026-10-13

Vocabulary, clarified by Noah on 2026-10-13: a REPOSITORY is the git repo (e.g. borg-collective). A WORKTREE is a linked checkout of it registered as its own directory (e.g. borg-collective-front-door, tmux window borg-door; borg-collective-nanoprobes, window borg-probes); several worktrees, each carrying a PROJECT, can be active on one repository at once. A PROJECT is a body of related requirements, PRs and work that can span repositories (the ratified 2026-08-24 meaning, formerly "program"). A STACK is the declared, ordered PR stack of a project (the manifest file and its rows); "stack" replaces "chain" everywhere (decided 2026-10-13, matching GitHub's "PR stacks" and the tool-neutral .stacks/ root). In user-facing text a registered directory is a "repository", and "worktree" is used where the distinction matters. Planning surfaces (PROJECT_PLAN.md, /borg-plan, /borg-assimilate) keep "project".

Queen (Noah, 2026-10-13; first recorded in https://github.com/noah-goodrich/borg-collective/pull/207 on 2026-09-16): the orchestrator session is the QUEEN in everything Noah sees (tmux window, claude --name, borg help, launch prompt, hook text, messages, living docs; the third name "Conductor" is retired). Internal and contract names stay: BORG_ORCHESTRATOR_ROOT, the session-mode value, scope.kind, every --json key, and agent role text.

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
`.borg-project` markers." Re-measured 2026-10-12 at commit `a2744df` over tracked `*.py` / `*.zsh` / `*.sh` / `*.bats`:

```
git ls-files "*.py" "*.zsh" "*.sh" "*.bats" \
  | xargs grep -oiE "project(s)?" | wc -l   ->  3911
git ls-files "*.py" "*.zsh" "*.sh" "*.bats" \
  | xargs grep -liE "project" | wc -l       ->   148
```

**3911 occurrences across 148 of 295 tracked code files** — roughly eight times the plan's estimate, and it does not
include markdown. Heaviest: `drone.zsh` (469), `borg.zsh` (306), `tests/cli_contract.bats` (286),
`borg_core/link/test_core.py` (134), `borg_core/link/test_shell.py` (118), `borg_core/link/core.py` (112).

The site inventory classifies all 3911 (2605 repository, 1023 contract, 183 external, 48 noise, 45 workstream, 7
ambiguous): `assets/2026-10-12-project-rename-inventory.md` and its `.tsv`. `noise` is the English word projection or
projected, or the verb "to project", which is not the noun at all; `repository` (2605) is the edit scope.

History, measured 2026-08-31 (the tree has grown since; superseded by the figures above): 3142 occurrences across 97
of 139 tracked code files. Heaviest then: `drone.zsh` (307), `tests/cli_contract.bats` (247), `borg.zsh` (232),
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

1. **Classify before renaming.** Produce the site inventory (done, see Acceptance criteria): for each of the 97 files
   (148 at the 2026-10-12 re-measure), which occurrences mean repository and which mean workstream. This is the
   actual work; the edit is mechanical afterward.
2. **Registry key last, behind a reader that accepts both.** Ship a reader tolerant of `projects` and
   `repositories`, let it run, then migrate the file, then drop the tolerance.
3. **`.borg-project` marker: decide whether to rename it at all.** A marker filename is not a user-facing surface,
   it is on-disk data in every registered repo and inside the distributed plugin. Renaming it needs a migration and
   buys little. Recommend keeping the filename and renaming only the variables that read it — record the decision
   either way.
4. **Tests and goldens move with each step**, never in a trailing commit.
5. Step R6 (Noah, 2026-10-13): after R5 and the chain-to-stack rename, one PR aligns skills/ and the user docs with the
   final vocabulary (repository, worktree, project, stack, Queen), plus one claude-plugins mirror rebuild PR so
   sessions see it. The inventory covered code files only, so R6 owns the markdown surfaces. The registry-key
   migration (projects -> repositories, behind a dual reader) follows R6 in its own PRs.

## Acceptance criteria

- [x] **A site inventory exists** classifying every occurrence as repository-sense or workstream-sense, with the
      workstream-sense sites listed explicitly so a later reader can see they were considered, not missed.
  - Verify: the inventory's total reconciles with the measured 3142, and a spot-check of 20 random sites agrees.
  - Done 2026-10-12: `assets/2026-10-12-project-rename-inventory.md` (+ `.tsv`), pinned to `a2744df`. Reconciles
    against the re-measured 3911 (the 3142 above predates tree growth), row by row; three blind spot-checks of 20
    (seeds 11, 29, 47, committed under `assets/`) agreed 60 of 60. A later pass added the `noise` sense and moved 48
    rows into it (from repository 9, external 30, ambiguous 9). Open for a human, not blocking this criterion: 7
    ambiguous rows and the judgment calls listed under "Known limits" in the inventory, which fix what the rename PRs
    may touch.
- [x] **The repository-sense rename lands** across `borg_core/`, `lib/`, `hooks/`, `borg.zsh`, `drone.zsh` and tests.
  - Verify: `make test` at the coverage floor, `make lint` exit 0, `bats tests/` green after each step, not just at
    the end.
  - Done 2026-10-14 (R6, whole-tree zero). R1 to R5 landed as #350 (`borg_core/link`), #352 (the rest of `borg_core`), #357 (`lib/` and `hooks/`), #369 (`borg.zsh`) and #370 (R5: `drone.zsh` and the remaining code surfaces); each ran `make test`, `make lint` and bats green before merge. The closing sweep ran over the tracked code files plus the extensionless `bin/` scripts, which the inventory never covered: `git ls-files '*.py' '*.zsh' '*.sh' '*.bats' 'bin/*'` (363 files on the merged tree), then `git grep -oiE "project(s)?"` over the same pathspecs. It finds 1603 matches in 173 files (the pin, `a2744df`, had 3911 in 148 files over the four extensions; `bin/` holds 23 of today's 1603). Each match was classified by the inventory's definitions, with every line left after stripping fixed-sense tokens read by hand: contract 1292 (registry key `projects`, `--json` keys, `project` wire fields, `.borg-project`, `BORG_PROJECT_NAME`, `BORG_WORK_PROJECTS`, `@project_dir`, flag names such as `--project`, `--projects` and `--migrate-project-state`, the session-mode value `project`, `PROJECT_PLAN`), external 198 (Claude Code's `~/.claude/projects` and project memory, Cortex `projects`, docker compose project names, Supabase projects, Jira project keys, `pyproject`, Claude Code's `CLAUDE_PROJECT_DIR` variable), workstream 58 (a manifest or plan describing a project, `Project Plan` titles, the infoviz specimen stories), noise 55 (projection, projected and the verb "to project"), repository 0. That sweep surfaced the last plain-word repository sites, all fixed in R6: the `bin/` scripts' own wording (`borg-notifyd`, `borg-cortex-watch`, `borg-resume`, `borg-usage-watch`, `link-parity-harness`), the `mark-closed <repository|sid>` usage in `lib/borg/resume-close.sh` and its test, and two test comments. Re-run on the merged tree after main moved (the registry key expand, the nanoprobe guard hook, the summary readers, the context diet and the chain-to-stack contract step): the same command went from 1492 matches at the first count to 1575, a net of 98 new matches against 15 removed, found by diffing the per-line output of the two trees. Every new match was read: 95 are contract (the registry key `projects` in the new key-expand code and tests, the `BORG_REGISTRY_NORM_JQ` filter and its comments, `BORG_WORK_PROJECTS`, `project` wire fields in fixtures) and 3 were plain repository-sense words in a test title, a test comment and a test's placeholder strip (`[<project>]` against a skill that now says `[<repository>]`), fixed in the fold, which brings the total to 1572 with repository 0. The 15 removed matches were all contract (jq filters that gained the normalizer prefix, `PROJECT_PLAN.md`). Re-run once more after main gained the compass reader (`borg_core/compass`), the context-diet stack manifest, `borg checkpoint-prepare` (`borg_core/checkpoint`) and the rewritten link-up skill: 1572 became 1603 in 173 files, a net of 31 new matches and none removed, found by diffing the per-line output against the previous count. Every new match was read: 29 are contract (nine `PROJECT_ROOT` headers, the wire key between `borg checkpoint-prepare` and the skill that reads it, in the verb, its tests and the bats harness; seventeen `PROJECT_PLAN.md` in the verb's plan discovery and its tests; three uses of the registry key `projects` in the compass reader's tests and in `borg_core/link/cli.py`) and 2 are external (Claude Code's `CLAUDE_PROJECT_DIR` substitution in the skill's injection line and the test title that names it). The compass package and the context-diet manifest hold no repository-sense word. Nine more matches were plain repository-sense words, fixed in this fold before the count: the `project_root` function in `borg_core/checkpoint/prepare_shell.py`, its "project root" step label, four references in its tests (now `repository_root`) and two bats case titles that called the header the git toplevel; the link-up skill's `<project>` and `<project root>` placeholders and its test pin now say repository too. The total is 1603 with repository 0.
- [ ] **The registry migrates without a flag day.** A borg install upgraded mid-session keeps working.
  - Verify: a test that reads a pre-migration registry and a post-migration registry through the same code path.
- [x] **The `.borg-project` decision is recorded** in CLAUDE.md with its reason, whichever way it goes.
  - Verify: the decision text exists and names the plugin-distribution constraint.
  - Done 2026-10-12 (rename PR R1): CLAUDE.md, Key Patterns, "Vocabulary: `repository` is the code word for a git repo". The filename is kept permanently, together with the `borg link --json` keys and `BORG_PROJECT_NAME`, and the entry names the plugin-distribution constraint.
- [x] **The plugin's MARKER-WALK block and the deployed skill agree with the repo**, since `borg setup` is not the
      only delivery path any more.
  - Verify: the deployed-artifact drift check, or a byte comparison of the two copies.
  - Done 2026-10-15: `diff -r skills/borg-link` against the plugin mirror is clean, the mirror having been rebuilt from main at 6927b4df (claude-plugins PR #74, release 0.9.7).

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
