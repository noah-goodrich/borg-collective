# Project to repository rename: site inventory

*Directive: [2026-08-31-project-to-repository-rename](../2026-08-31-project-to-repository-rename.md), first acceptance criterion.*
*Pinned to commit `a2744df` (main, 2026-10-12). Companion data: `2026-10-12-project-rename-inventory.tsv`.*

This is the classification the directive calls "the actual work". Every occurrence of `project` or `projects` (case-insensitive) in tracked `*.py`, `*.zsh`, `*.sh` and `*.bats` files at `a2744df` has one row in the TSV, with a sense. The rename itself has not started. Line numbers are pinned to `a2744df` and drift as main moves; anchor on file plus the quoted code, not the number.

## Method

- **The grep.** The directive's own measurement, re-run at the pinned commit (the `-n` variant of the same match, so rows carry line numbers):

```
git ls-files "*.py" "*.zsh" "*.sh" "*.bats" \
  | xargs grep -oiE "project(s)?" | wc -l
```

- **One row per match.** A row is `file, line, nth, match, sense, note`. `nth` is the 1-based index of the match on its line, so two matches on one line are two rows.
- **Taxonomy.** Five senses:
  - `repository`: the word means a registered git repo, its directory or its name. This is the edit scope of the rename.
  - `workstream`: the word means work spanning one or more repositories (the plan's "Project"). Must NOT be renamed.
  - `contract`: the word is part of a name other code or data depends on (registry key, wire key, marker, filename, env var). Renamed separately, with a migration.
  - `external`: another system's own word (Claude Code's `~/.claude/projects`, Supabase `project_id`, docker compose, `pyproject`). Never renamed. Some shards also filed English-word noise here, see "Known limits".
  - `ambiguous`: could not be settled from the line; listed below for a human.
- **Shards.** 13 shards split the 148 files by size, each classified by a separate agent with rules keyed on the text around each match, plus per-site overrides. Shard classifiers read the grep lines with context, not every file whole. The `note` column is generic per rule, not per row. The repository rows are the default and the least checked.
- **Blind spot-checks.** Three auditors, seeds 11, 29 and 47, each drew 20 rows with `random.Random(seed)` from the 3911, read the code at each site first and chose a sense before seeing the inventory's.
- **Merge.** The 13 shard files were concatenated and sorted by file, line, nth. No row was edited.

## Totals by sense

| sense      | rows | share |
|------------|------|-------|
| repository | 2614 | 66.8% |
| contract   | 1023 | 26.2% |
| external   | 213  | 5.4%  |
| workstream | 45   | 1.2%  |
| ambiguous  | 16   | 0.4%  |
| total      | 3911 | 100%  |

By shard (files, rows, then rows per sense):

| shard | files | rows | repo | work | ext | con | amb |
|-------|-------|------|------|------|-----|-----|-----|
| 0     | 1     | 469  | 432  | 0    | 14  | 23  | 0   |
| 1     | 1     | 286  | 164  | 0    | 0   | 122 | 0   |
| 2     | 1     | 306  | 240  | 0    | 0   | 57  | 9   |
| 3     | 3     | 270  | 150  | 0    | 0   | 120 | 0   |
| 4     | 4     | 318  | 263  | 0    | 5   | 50  | 0   |
| 5     | 5     | 292  | 172  | 0    | 20  | 100 | 0   |
| 6     | 5     | 290  | 201  | 0    | 1   | 87  | 1   |
| 7     | 6     | 319  | 259  | 0    | 1   | 59  | 0   |
| 8     | 9     | 300  | 199  | 3    | 22  | 76  | 0   |
| 9     | 11    | 316  | 177  | 15   | 5   | 118 | 1   |
| 10    | 18    | 290  | 140  | 0    | 40  | 110 | 0   |
| 11    | 31    | 307  | 156  | 18   | 69  | 64  | 0   |
| 12    | 53    | 148  | 61   | 9    | 36  | 37  | 5   |
| all   | 148   | 3911 | 2614 | 45   | 213 | 1023| 16  |

Heaviest files: `drone.zsh` 469, `borg.zsh` 306, `tests/cli_contract.bats` 286, `borg_core/link/test_core.py` 134, `borg_core/link/test_shell.py` 118, `borg_core/link/core.py` 112, `borg_core/link/render.py` 110.

## Reconciliation

| measure                   | at a2744df |
|---------------------------|------------|
| grep -oiE matches         | 3911       |
| inventory rows            | 3911       |
| files with a match        | 148        |
| distinct files in the TSV | 148        |
| tracked code files        | 295        |

The rows reconcile exactly. Beyond the equal totals, the TSV was joined to `git grep -noiE "project(s)?" a2744df` on file, line, nth and the matched text: 0 matches have no row, 0 rows have no match, 0 duplicate keys, and every `match` column equals the text grep returned. Every row has 6 tab-separated fields and one of the five senses.

- **The directive's old numbers do not match this tree, and that is drift, not an inventory error.** The directive measured 3142 occurrences across 97 of 139 tracked code files on 2026-08-31. At `a2744df` the same command gives 3911 across 148 of 295. The tree grew in the two months between, and the difference is not attributed here. The directive's Measured scope section now carries the re-measured figures and keeps the old ones as history.
- **Main has moved since the pin.** At `d96ea15` (two commits later) the same grep gives 3914 matches in 149 files: three more matches and one more file. They are not in the inventory. Re-measure before the first rename PR and extend the TSV for the delta.


## Workstream-sense sites (all 45 rows)

The criterion asks for these to be listed so a later reader can see they were considered, not missed. 45 rows on 39 lines in 9 files, every one of them prose or an identifier that uses "project" in the plan's vocabulary: work spanning one or more repositories. A rename script must skip them. Each bullet is `file:line (matches on that line)` and the code, trimmed.

- `borg_core/link/picture.py:314` (project) `project is essentially done, from a field no sweep and no fetch ever saw.`
- `borg_core/link/picture.py:620` (project) `top-left node of the first project.`
- `borg_core/link/test_grid.py:2302` (project) `` lives in `o/tracker`, a repository this project does not span. Listing it would tell a reader the ``
- `borg_core/link/test_grid.py:2303` (project) `project reaches a repository it merely files its tracker in -- under a heading that already claims`
- `borg_core/link/test_grid.py:2304` (project) `the project. Sorted and deduplicated, so two rows in one repository contribute one entry.`
- `borg_core/link/test_picture.py:844` (project) `# 2 unknown, and a glance strip of twelve green checkmarks asserting a project is essentially done`
- `borg_core/manifest/across.py:52` (projects) `` `contested_refs` is the contested-ref half of the deleted merge-tree/gather.py's `apply_program_p... ``
- `borg_core/manifest/across.py:82` (project) `under exactly one repository, so a second project that depends on one of its rows declares that`
- `borg_core/manifest/across.py:181` (projects) `pointers at work happening somewhere else. Two projects sharing one tracker issue is not a`
- `borg_core/manifest/across.py:182` (projects) `` contest, and two projects where one `after`-points at the other's row is the NORMAL ``
- `borg_core/manifest/across.py:183` (project) `cross-project case that manifests exist to express -- reporting either as contested turns the`
- `borg_core/manifest/across.py:185` (project) `includes the apex because it uses the same map to REGROUP items onto a project, which is a`
- `borg_core/manifest/core.py:49` (project, project) `A chain describes a project, and a project has the ticket that asked for it and the document that`
- `borg_core/manifest/core.py:62` (project) `VOCABULARY. A *repository* is a git repo; a *project* is work spanning one or more repositories.`
- `borg_core/manifest/core.py:742` (project) `happening somewhere else. Scoping on the wider set puts another project's ENTIRE grid under this`
- `borg_core/manifest/core.py:743` (project) `repository's header the moment this repository merely hosts its tracker issue or one cross-project`
- `borg_core/manifest/core.py:795` (project) `for what hosting another project's tracker would otherwise do to this repository's grid.`
- `borg_core/manifest/test_across.py:82` (projects) `"""Two projects naming the same dependency is normal input, so the duplicate is dropped rather`
- `borg_core/manifest/test_across.py:364` (projects) `"""Two projects tracked by one issue is coordination, not a conflict. merge-tree's copy includes`
- `borg_core/manifest/test_across.py:365` (project) `the apex because it regroups items onto a project with the same map; that job stays over there.`
- `borg_core/manifest/test_across.py:383` (project, project) `"""This is the NORMAL cross-project case manifests exist to express: one project's row merges`
- `borg_core/manifest/test_core.py:298` (projects, project) `Chains describe projects, and a project is not only its pull requests -- it has a ticket that`
- `borg_core/manifest/test_core.py:1188` (projects) `def test_hosting_a_tracker_or_a_blocker_does_not_select_another_projects_grid():`
- `borg_core/manifest/test_core.py:1190` (project) `# a repository which merely HOSTS another project's tracker issue -- or is named by one`
- `borg_core/manifest/test_core.py:1191` (project, project) `# cross-project blocker -- rendered that project's entire grid, none of whose rows belong to it,`
- `docs/infoviz/harness/build-specimens.py:6` (project) `measures recall, not comprehension. Randomising which project is urgent restores most of the test's`
- `docs/infoviz/harness/build-specimens.py:73` (project) `"""Permute project priority order and plant needs_you on exactly one workstream.`
- `docs/infoviz/harness/build-specimens.py:79` (projects, projects) `projects = list(story.get("projects", []))`
- `docs/infoviz/harness/build-specimens.py:80` (projects) `rng.shuffle(projects)`
- `docs/infoviz/harness/build-specimens.py:81` (projects) `for i, p in enumerate(projects, start=1):`
- `docs/infoviz/harness/build-specimens.py:86` (project) `# Plant the signal on a project that is NOT rank 1, so "it's just the top card" doesn't win by`
- `docs/infoviz/harness/build-specimens.py:89` (projects) `candidates = [p for p in projects[1:] if p.get("workstreams")]`
- `docs/infoviz/harness/build-specimens.py:90` (projects) `target = rng.choice(candidates) if candidates else projects[0]`
- `docs/infoviz/harness/build-specimens.py:96` (projects, projects) `story["projects"] = projects`
- `docs/infoviz/harness/build-specimens.py:98` (project) `"needs_you_project_id": target.get("id"),`
- `docs/infoviz/harness/build-specimens.py:99` (project) `"needs_you_project_name": target.get("name"),`
- `docs/infoviz/harness/build-specimens.py:100` (project) `"needs_you_project_rank": target.get("priority"),`
- `docs/infoviz/harness/build-specimens.py:214` (projects) `print("  story-lens.html   (shuffled projects, needs-you planted)")`
- `merge-tree/test_s4_manifests.py:55` (project) `# Lifecycle naming rule: the id IS user-facing (it becomes the project id in every view), so it`

- Notes on the list: `docs/infoviz/harness/build-specimens.py` (15 rows) is a specimen generator whose `story.json` "projects" each hold "workstreams", so its story-lens rows are workstream while the same file's registry-fixture rows are repository or contract. `borg_core/manifest/core.py:62` is the vocabulary statement itself. Every other site is a docstring, comment or test name in the manifest and link code that describes a chain or grid as a project spanning repositories.
- Not in this list but close: the user-facing strings "no project manifests in the registry yet" and "no project manifest declares work in ..." (12 rows: `borg_core/link/render.py` 665, 677, 703, 706; `borg_core/link/test_render.py` 170, 172, 201, 210, 211, 219; `tests/cli_contract.bats` 3449, 3474) are classed repository, and a manifest is a chain that spans repositories, so these may belong here. Flagged by the shard 1 classifier; not an auditor disagreement; left as classified. See "Known limits".

## Ambiguous sites (all 16 rows, for a human)

16 rows on 16 lines in 5 files. Suggested disposition in the bullets below the list.

- `borg.zsh:1291` (projects) `` # `_borg_py borg_core.link.cli --json` every other dispatch arm builds — projects that JSON into the ``
- `borg.zsh:1368` (projects) `` # `.order` is the post-archived-filter list, and it is EXACTLY the list this function projects ``
- `borg.zsh:1382` (project) `# into the next column. The projection is deliberately NARROWER than the document (~40KB raw,`
- `borg.zsh:1403` (project) `` # `render._scoped_rows` reads `doc.focus[key]` when `scope.kind == "repository"`. A projection ``
- `borg.zsh:1414` (project) `local jq_stderr_file="$(_borg_state_root)/briefing-projection-stderr.log"`
- `borg.zsh:1476` (project) `` # board row by the short circuit above, so a `payload` of zero bytes can only mean the projection ``
- `borg.zsh:1485` (project) `fallback_reason="the document projection produced nothing"`
- `borg.zsh:1514` (project) `# THE WHOLE NARRATIVE HALF IS SKIPPED WHEN THERE IS NOTHING TO NARRATE FROM. A projection failure`
- `borg.zsh:3214` (Project) `/borg-plan              Project planning + Collective review`
- `borg_core/link/test_cli.py:410` (projects) `` `borg link --brief` builds the document ONCE with `--json`, projects it into the narrative ``
- `borg_core/manifest/test_shell.py:1796` (projects) `` merge-tree's `apply_program_projects` reads each manifest's top-level `program` key and SKIPS any ``
- `evals/lifecycle-manifests/fixtures.sh:141` (PROJECT) `# A repository holding a SMALL REAL PROJECT: source, a test, and a README naming a genuine gap.`
- `evals/lifecycle-manifests/fixtures.sh:152` (project) `_eval_repo_with_project() {`
- `evals/lifecycle-manifests/fixtures.sh:163` (project) `git -C "$dir" commit --quiet -m "real project" >/dev/null 2>&1`
- `lib/desktop.zsh:32` (project) `local project="${topic:-$name}"`
- `lib/desktop.zsh:43` (project) `--arg display_name "$project" \`

- **English verb or noun, no rename (9 rows).** `borg.zsh` 1291, 1368, 1382, 1403, 1414, 1476, 1485, 1514 and `borg_core/link/test_cli.py:410` are "projects" (verb) or "projection", not the noun. Suggested: move to `external` or a new noise sense.
- **A real call, `borg.zsh:3214` (1 row).** The `/borg-plan` help line "Project planning + Collective review". The skill plans work that may span repositories, so it is plausibly workstream; it is also the help text for a per-repository command. Needs Noah.
- **Retired name, no rename (1 row).** `borg_core/manifest/test_shell.py:1796` quotes `apply_program_projects`, a merge-tree function that no longer exists. Suggested: external (a historical name in a docstring).
- **Generic English in eval fixtures (3 rows).** `evals/lifecycle-manifests/fixtures.sh` 141, 152, 163: "a small real project", the helper name `_eval_repo_with_project` and a commit message. They describe a fixture git repo, so repository is likely right for 152 and 141; 163 is a commit message string. Needs a reader.
- **Claude Desktop display name (2 rows).** `lib/desktop.zsh` 32 and 43 build a topic display name for a registry entry that has no repository. Likely repository (a local variable); depends on whether the Desktop concept is a "Project" in Claude's own sense.

## Contract-sense breakdown (1023 rows)

A contract name is one that other code, hooks, the plugin or on-disk data read, so renaming it needs a migration or a deprecation path. The table groups the rows by the identifier the match sits inside, derived from the code on each line rather than from the note column.

| contract name                         | rows |
|---------------------------------------|------|
| `projects` (key, flag, jq path)       | 573  |
| `project` (field or value, see below) | 166  |
| `PROJECT_PLAN.md` and `PROJECT_PLAN`  | 107  |
| `total_projects` (link --json)        | 55   |
| `.borg-project` marker                | 35   |
| projects.json / `projects_file`       | 23   |
| `items_by_project` (recon doc)        | 17   |
| `@project_*`, `tmux.project_dir`      | 15   |
| env vars (see below)                  | 14   |
| other identifiers embedding a name    | 12   |
| `__PROJECT_NAME__` placeholders       | 6    |
| total                                 | 1023 |

- **The registry key is most of the first row.** 573 rows read `projects`, and the token-level grouping cannot separate the registry key from the `borg link --json` document key and the recon `--projects` flag, which share the spelling. By the shard notes the registry key, its jq paths and its fixtures dominate; the flag is the smaller group.
- **Env vars:** `BORG_WORK_PROJECTS` 10 rows, `BORG_PROJECT_NAME` 4 rows.
- **The `project` rows (166) are wire fields and values:** the recon Item key, the `borg next --json` row key and its chooser fixtures, the `project` field of `token-spend.jsonl` and `cortex-wakes.json` records, the `project` key of resume session and ledger files, the session-mode value `project` returned by `_borg_session_mode`, and `# Project Plan:` heading text inside PROJECT_PLAN.md fixtures.
- **`.borg-project`** (35 rows): the marker filename, written by `drone.zsh`, read by `lib/borg-hooks.sh`, hard-coded in `hooks/bash-guard.sh` and present in the `borg-link` skill's MARKER-WALK block. The directive's third change item says to keep the filename and decide either way in CLAUDE.md.
- **State-root `projects/`**: about 17 rows name the on-disk `projects/<key>/state.json` directory (`lib/borg-hooks.sh`, `borg_core/statemigrate`), counted inside the `projects` row above because the token is the same. It is on-disk data, not a key in a shared file.
- **Template placeholders** (6 rows) can be renamed only together with the files under `templates/` and `drone.zsh`.
- **Debatable contract calls the shards flagged** and that a human should confirm before treating them as frozen: tmux window options `@project_dir`/`@project_name` (internal to tmux but possibly read elsewhere), the `recon --projects` flag and the adapter `projects.json` file (renameable behind a deprecation alias), the `assemble(projects=...)` kwargs, the `"Project Plan: Delta/Nox"` fixture bodies, and the `project` key in cortex-wakes fixtures (not checked against Cortex's own spelling).

## External-sense breakdown (213 rows)

- `~/.claude/projects` and Claude Code's per-cwd session and memory directories, `claude_project_dir` helpers, the Claude `project_*.md` memory file names: about 110 rows.
- `pyproject` / `pyproject.toml`: about 25 rows.
- English-word noise filed under external by shards 5, 8, 9, 10 and 11: "projection", "projected", "projectpath" and similar, about 30 rows.
- Docker compose project label/name (about 17), Supabase `project_id` / `--project-ref` / remote project (about 14), Cortex projects dir (about 8), plus single rows for Jira's project key, `cargo locate-project`, cairn's project search and Claude Desktop's Project feature.

These counts are approximate, read from the free-text note column; the sense column is the data of record.

## Blind spot-checks

Three auditors, 20 rows each, 60 rows in total, drawn with `random.Random(seed)` over the 3911 rows. Each read the code at the site first and picked a sense, then compared.

| seed | sampled | agreed | disagreed |
|------|---------|--------|-----------|
| 11   | 20      | 20     | 0         |
| 29   | 20      | 20     | 0         |
| 47   | 20      | 20     | 0         |
| all  | 60      | 60     | 0         |

- **The sample by inventory sense:** 45 repository, 9 contract, 5 external, 1 workstream, 0 ambiguous. The workstream and ambiguous senses are barely tested by it (1 of 61 rows); the 45 workstream rows were instead each read for this document (listed above) and the sense holds on each.
- **Corrections: none.** No auditor disagreement was found, so no row was changed. The auditors' raw samples are not committed (they live in `/private/tmp/rename-inv/audit-*/full.tsv`, outside the repository).
- **Taxonomy remarks the auditors made, agreed on the row but worth acting on:** `grid.py:925` ("projection") and `grid.py:167` ("projected") are substring false positives filed under `external`, which stretches the definition of that sense. If rename tooling treats `external` as foreign vocabulary, add a `noise` sense for them. Three rows were close calls resolved toward the inventory: `build-specimens.py:80` (workstream, a variable use), `test_core.py:793` (`projects={}` kwarg mirroring the link --json key, contract) and `nextpick/core.py:481` (`"project": row["project"]` wire key, contract). `briefing.bats:269` has "project" inside an invented repo name and is repository.

## Known limits

- **The classification is rule-based.** Each shard classifier applied rules to the text around each match and overrode by site. Nobody read all 3911 rows; the repository rows (2614, the edit scope) are the default and are the least checked. 45 of the 60 audited rows were repository and all 45 agreed, which bounds nothing tighter than a spot-check.
- **Substring noise is filed inconsistently.** A mechanical check of the code on each line finds 101 rows where the match sits inside a longer word: 54 external, 41 repository, 6 ambiguous. The repository 41 are mostly real identifiers (`ProjectNotFound` 15, `myproject` 15, `nosuchproject` 3, test names 2, `aproject` 1), but 5 are English words that should not be edited: `borg.zsh:1475` ("EMPTY PROJECTION") and the variable `projected` at `borg_core/recon/test_core.py` 377, 378, 379, 380. Left as classified; if they are corrected to `external`, repository becomes 2609 and external 218.
- **`--migrate-project-state` is classed inconsistently.** 18 rows on lines that mention the flag or its Python spelling are repository and 1 is contract. It is a CLI flag, so it may need a deprecation alias like the other contract names. Decide once before the rename.
- **The "no project manifest(s)" strings** (12 rows, listed above) are repository but may be workstream.
- **`PROJECT_PLAN.md` is contract by decision of the classifiers**, not the directive. The directive does not mention renaming it; treat the 107 rows as frozen unless that changes.
- **Line numbers drift.** They are exact at `a2744df` only. Use `file` plus the quoted code to relocate a row on a newer tree.

## What this means for the rename PRs

- **The edit scope is the 2614 repository rows,** about two thirds of the occurrences. The other 1297 rows (contract, external, workstream, ambiguous) must not be touched by a mechanical pass.
- **Contract names migrate separately,** each behind a reader that accepts both spellings, per the directive: the registry key `projects` last, after every reader tolerates `repositories`. The `--json` document keys (`projects`, `total_projects`, row key `project`) are a wire change for the `borg-link` skill and need a `DOCUMENT_VERSION` decision.
- **`.borg-project` and `PROJECT_PLAN.md` are decisions, not edits,** per the directive's third change item.
- **Resolve the 16 ambiguous rows and the flagged judgment calls first;** they are a few dozen rows and each one changes what a rename script may touch.
