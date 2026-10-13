# Project to repository rename: site inventory

*Directive: [2026-08-31-project-to-repository-rename](../2026-08-31-project-to-repository-rename.md), first acceptance criterion.*
*Pinned to commit `a2744df` (main, 2026-10-12). Companion data: `2026-10-12-project-rename-inventory.tsv`.*

This is the classification the directive calls "the actual work". Every occurrence of `project` or `projects` (case-insensitive) in tracked `*.py`, `*.zsh`, `*.sh` and `*.bats` files at `a2744df` has one row in the TSV, with a sense. The first pass used five senses; a second pass (2026-10-12) added a sixth, `noise`, and moved 48 rows into it. The rename started with R1 (PR #350) and continued with R2 (PR #352); see "Relabels after R1", "Relabels after R2", "Relabels after R3", "Relabels after R4" and "Relabels after R5". Line numbers are pinned to `a2744df` and drift as main moves; anchor on file plus the quoted code, not the number.

## Method

- **The grep.** The directive's own measurement, re-run at the pinned commit (the `-n` variant of the same match, so rows carry line numbers):

```
git ls-files "*.py" "*.zsh" "*.sh" "*.bats" \
  | xargs grep -oiE "project(s)?" | wc -l
```

- **One row per match.** A row is `file, line, nth, match, sense, note`. `nth` is the 1-based index of the match on its line, so two matches on one line are two rows.
- **Taxonomy.** Six senses:
  - `repository`: the word means a registered git repo, its directory or its name. This is the edit scope of the next rename PR, and only these rows.
  - `workstream`: the word means work spanning one or more repositories (the plan's "Project"). Must NOT be renamed.
  - `contract`: the word is part of a name other code or data depends on (registry key, wire key, marker, filename, env var). Renamed separately, with a migration.
  - `external`: another system's own word (Claude Code's `~/.claude/projects`, Supabase `project_id`, docker compose, `pyproject`). Never renamed. Before the `noise` sense existed some shards filed English-word false positives here; those rows have moved.
  - `ambiguous`: could not be settled from the line; listed below for a human.
  - `noise`: the match does not refer to the noun "project" at all. Two cases only. (a) The match is part of a different English word: the whole word token containing it is projection(s), projected, projecting, projector(s), projective, projectile(s) or a prefixed form (reprojected, unprojected). (b) The English verb "to project" (to cast, map or display one thing onto another), as in "project the document into the prompt". An identifier or name that contains the noun as a component (`project_dir`, `PROJECT_PLAN`, `myproject`, `pyproject`, `projectPath`, `BORG_PROJECT_NAME`) is not noise and keeps its sense. A rename script must skip these rows; they are not even foreign vocabulary, they are other words.
- **Shards.** 13 shards split the 148 files by size, each classified by a separate agent with rules keyed on the text around each match, plus per-site overrides. Shard classifiers read the grep lines with context, not every file whole. The `note` column is generic per rule, not per row. The repository rows are the default and the least checked.
- **Blind spot-checks.** Three auditors, seeds 11, 29 and 47, each drew 20 rows with `random.Random(seed)` from the 3911, read the code at each site first and chose a sense before seeing the inventory's.
- **Merge.** The 13 shard files were concatenated and sorted by file, line, nth. No row was edited at merge.
- **Noise pass.** After the audits, every row whose match text could be case (a) or (b) was re-read in its line at `a2744df`. For (a), every row was checked mechanically for a longer word: the run of letters around the match, read from the line; the only such words are projected and projection, and the rest of the longer-word rows (`pyproject`, `myproject`, `ProjectNotFound`, `projectPath`) are identifiers and stayed. For (b), the two rows the first draft and a reviewer flagged (`borg.zsh:1475`, `borg_core/recon/test_core.py` 377-380) turned out to be case (a), and a scan of the remaining rows for verb-shaped context (a modal, `which`/`that`/`it` before the word, or `it`/`them`/`into`/`onto`/`away` after it, including a word at the end of a comment line with the object on the next line) found 10 verb rows. Only rows that met the definition were reclassified; the old sense is in the note column (for example `noise: projection; was external`). See "Noise-sense sites" and "Known limits" for what this scan does not prove.

## Totals by sense

| sense      | rows | share |
|------------|------|-------|
| repository | 2507 | 64.1% |
| contract   | 1089 | 27.8% |
| external   | 191  | 4.9%  |
| workstream | 75   | 1.9%  |
| noise      | 49   | 1.3%  |
| ambiguous  | 0    | 0.0%  |
| total      | 3911 | 100%  |

Before the noise pass the table read repository 2614, contract 1023, external 213, workstream 45, ambiguous 16. The 48 noise rows came from repository (9), external (30) and ambiguous (9); contract and workstream lost none. The R1 relabel (PR #350, 2026-10-12) then moved 27 rows from repository to workstream and 12 from repository to contract; see "Relabels after R1" below. The pin is still `a2744df`: R1 renamed code but this table does not follow the renames, so a row R1 renamed keeps its `repository` label. The R2 relabel (PR #352, 2026-10-12) then moved 27 rows from repository to contract and 3 from repository to external, and 2 rows from contract to repository; see "Relabels after R2" below. The same rule holds: a row R2 renamed keeps its `repository` label. The R3 relabel (PR #357, 2026-10-13) then moved 5 rows from repository to contract; see "Relabels after R3" below. The R4 relabel (PR #369, 2026-10-13) then moved 5 rows from repository to contract, 2 from repository to workstream and 1 from ambiguous to workstream, and 10 rows from contract back to repository; see "Relabels after R4" below. The R5 relabel (Part A, `drone.zsh`, 2026-10-13) then moved 3 rows from repository to contract (1) and external (2); see "Relabels after R5" below. The R5 relabel (Part B, `merge-tree/`, `evals/`, `templates/`, `install.sh`, the `docs/` code files and the closing sweep, 2026-10-13) then moved 28 rows from repository to contract, 2 to external and 1 to noise, and settled all six ambiguous rows (5 to repository, 1 to external); see "Relabels after R5" below.

By shard (files, rows, then rows per sense):

| shard | files | rows | repo | work | ext | con | amb | noise |
|-------|-------|------|------|------|-----|-----|-----|-------|
| 0     | 1     | 469  | 429  | 0    | 16  | 24  | 0   | 0     |
| 1     | 1     | 286  | 160  | 2    | 0   | 122 | 0   | 2     |
| 2     | 1     | 306  | 238  | 0    | 0   | 57  | 1   | 10    |
| 3     | 3     | 270  | 150  | 0    | 0   | 120 | 0   | 0     |
| 4     | 4     | 318  | 241  | 9    | 5   | 62  | 0   | 1     |
| 5     | 5     | 292  | 163  | 9    | 1   | 100 | 0   | 19    |
| 6     | 5     | 290  | 201  | 0    | 1   | 87  | 0   | 1     |
| 7     | 6     | 319  | 259  | 0    | 1   | 59  | 0   | 0     |
| 8     | 9     | 300  | 193  | 5    | 19  | 76  | 0   | 7     |
| 9     | 11    | 316  | 177  | 15   | 4   | 118 | 1   | 1     |
| 10    | 18    | 290  | 135  | 5    | 36  | 110 | 0   | 4     |
| 11    | 31    | 307  | 156  | 18   | 66  | 64  | 0   | 3     |
| 12    | 53    | 148  | 61   | 9    | 36  | 37  | 5   | 0     |
| all   | 148   | 3911 | 2507 | 75   | 191 | 1089| 0   | 49    |

The shard rows above are the classification record and follow the R1 relabel only. The R2 relabel moved 30 rows out of repository and 2 back in, in files of shards 3 to 12, and the TSV does not record shard membership, so the shard rows no longer sum to the `all` row: they total repository 2566, contract 1035 and external 183.

Heaviest files: `drone.zsh` 469, `borg.zsh` 306, `tests/cli_contract.bats` 286, `borg_core/link/test_core.py` 134, `borg_core/link/test_shell.py` 118, `borg_core/link/core.py` 112, `borg_core/link/render.py` 110.

## Reconciliation

| measure                   | at a2744df |
|---------------------------|------------|
| grep -oiE matches         | 3911       |
| inventory rows            | 3911       |
| files with a match        | 148        |
| distinct files in the TSV | 148        |
| tracked code files        | 295        |

The rows reconcile exactly. Beyond the equal totals, the TSV was joined to `git grep -noiE "project(s)?" a2744df` on file, line, nth and the matched text: 0 matches have no row, 0 rows have no match, 0 duplicate keys, and every `match` column equals the text grep returned. Every row has 6 tab-separated fields and one of the six senses. The join was run on the first draft of the TSV; the noise pass changed only the `sense` and `note` columns of 48 rows and the R1 relabel only those columns of 52 more, and the data-row count, the keys and the `match` column are unchanged.

- **The directive's old numbers do not match this tree, and that is drift, not an inventory error.** The directive measured 3142 occurrences across 97 of 139 tracked code files on 2026-08-31. At `a2744df` the same command gives 3911 across 148 of 295. The tree grew in the two months between, and the difference is not attributed here. The directive's Measured scope section now carries the re-measured figures and keeps the old ones as history.
- **Main has moved since the pin.** At `d96ea15` (two commits later) the same grep gives 3914 matches in 149 files: three more matches and one more file. They are not in the inventory. Re-measure before the first rename PR and extend the TSV for the delta.


## Workstream-sense sites (all 75 rows)

The criterion asks for these to be listed so a later reader can see they were considered, not missed. 75 rows on 68 lines in 15 files. R4 (#369) added 3 rows in `borg.zsh` (see its bullets first below). 45 rows were classed workstream in the first pass: prose or an identifier that uses "project" in the plan's vocabulary, work spanning one or more repositories. R1 (#350) added 27 rows where "project" means a chain manifest and the code now says "chain"; their note starts "chain manifest: reworded to chain in #350", and so do 6 of the original rows that R1 reworded the same way. A rename script must skip them. Each bullet is `file:line (matches on that line)` and the code, trimmed.

- `borg.zsh:1523` (project) `"PROJECT MANIFEST: \($m.id) — ..."` and `borg.zsh:1574` (project) `Prefer a READY ref from a project manifest`: the briefing prompt's label and instruction for a chain manifest (R4 kept them)
- `borg.zsh:3214` (Project) `/borg-plan              Project planning + Collective review`: planning surfaces keep the word (Noah, 2026-10-13); was ambiguous
- `borg_core/link/grid.py:634` (project) `would render another project's entire grid under this repository's header, a wrong answer rather`
- `borg_core/link/grid.py:898` (project) `"repos:" line under a project's heading.`
- `borg_core/link/grid.py:903` (project) `Listing those would tell a reader this project spans a repository it merely references -- and`
- `borg_core/link/grid.py:904` (project) `would do it under a heading that already claims the project, which is the wrong-answer-under-a-`
- `borg_core/link/picture.py:314` (project) `project is essentially done, from a field no sweep and no fetch ever saw.`
- `borg_core/link/picture.py:620` (project) `top-left node of the first project.`
- `borg_core/link/render.py:665` (project) `only manifest has one bad row rendered "no project manifests in the registry yet. Run /borg-plan`
- `borg_core/link/render.py:677` (project) `the registry-wide sentence claim "no project manifests in the registry yet" while three of them`
- `borg_core/link/render.py:703` (project) `return "no project manifests in the registry yet. Run /borg-plan in any repository."`
- `borg_core/link/render.py:706` (project) `return f"no project manifest declares work in {grid_block['slug']}. Run /borg-plan to scaffold one."`
- `borg_core/link/render.py:710` (project) `"""One project's CHAINS block: its heading, the picture, then one detail block per node.`
- `borg_core/link/render.py:738` (project) `` project, with GLOBAL node ids so `*` in vim toggles between a cell and its detail exactly once. ``
- `borg_core/link/render.py:740` (projects) `` The note is UNCONDITIONAL, even when no manifest was selected: `0 projects · 0 refs · 0 ``
- `borg_core/link/render.py:764` (project, projects) `f"{_plural(len(manifests), 'project', 'projects')}"`
- `borg_core/link/test_grid.py:289` (project) `must then reject it rather than render another project's whole grid under this repository's`
- `borg_core/link/test_grid.py:765` (project) `project's entire grid rendered under this repository's header.`
- `borg_core/link/test_grid.py:2302` (project) `` lives in `o/tracker`, a repository this project does not span. Listing it would tell a reader the ``
- `borg_core/link/test_grid.py:2303` (project) `project reaches a repository it merely files its tracker in -- under a heading that already claims`
- `borg_core/link/test_grid.py:2304` (project) `the project. Sorted and deduplicated, so two rows in one repository contribute one entry.`
- `borg_core/link/test_picture.py:844` (project) `# 2 unknown, and a glance strip of twelve green checkmarks asserting a project is essentially done`
- `borg_core/link/test_render.py:170` (project) `({"scope_kind": "orchestrator", "slug": ""}, "no project manifests in the registry yet"),`
- `borg_core/link/test_render.py:172` (project) `({"scope_kind": "repository", "slug": "acme/ledger"}, "no project manifest declares work in acme/led...`
- `borg_core/link/test_render.py:201` (project) `A repository whose only manifest was refused used to render "no project manifests in the registry`
- `borg_core/link/test_render.py:210` (project) `assert "no project manifests in the registry yet" not in page`
- `borg_core/link/test_render.py:211` (project) `assert "no project manifest declares work in acme/ledger" not in page`
- `borg_core/link/test_render.py:219` (project) `assert "no project manifest declares work in acme/ledger" in render.document(doc)`
- `borg_core/link/test_render.py:229` (project) `so an orchestrator page with unreadable manifests on disk must not print "no project manifests in`
- `borg_core/link/test_render.py:237` (project) `assert "no project manifests in the registry yet" not in page`
- `borg_core/link/test_render.py:249` (project) `assert "no project manifests in the registry yet" in out`
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
- `borg_core/manifest/shell.py:316` (project) `copy and the CHAINS placeholder silently reverts to the false "no project manifests in the`
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
- `tests/cli_contract.bats:3449` (project) `run grep -c 'no project manifest declares work in acme/ledger' "${BATS_TEST_TMPDIR}/ledger.txt"`
- `tests/cli_contract.bats:3474` (project) `run grep -c 'no project manifests in the registry yet' "${BATS_TEST_TMPDIR}/orch-empty.txt"`

- Notes on the list: `docs/infoviz/harness/build-specimens.py` (15 rows) is a specimen generator whose `story.json` "projects" each hold "workstreams", so its story-lens rows are workstream while the same file's registry-fixture rows are repository or contract. `borg_core/manifest/core.py:62` is the vocabulary statement itself. Every other site is a docstring, comment or test name in the manifest and link code that describes a chain or grid as a project spanning repositories.
- Chain manifests: the user-facing strings "no project manifests in the registry yet", "no project manifest declares work in ..." and the CHAINS count "N projects" were classed repository in the first pass (the shard 1 classifier flagged them). Noah's R1 decision (2026-10-12) is that "chain" is the word for a manifest, so they now read "chain" and sit here with the comments, docstrings and tests that mean the same thing (`grid.py`, `render.py`, `picture.py`, `manifest/shell.py`, their tests and goldens).

## Ambiguous sites (all 6 rows, for a human)

All six were settled by R5 Part B (2026-10-13), each as the suggestion below proposed; see "Relabels after R5". The list is kept as the record of what was open.

6 rows on 6 lines in 3 files. The first draft listed 16; the 9 English-word rows (`borg.zsh` 1291, 1368, 1382, 1403, 1414, 1476, 1485, 1514 and `borg_core/link/test_cli.py:410`) are now `noise`, see below. What remains:

- `borg_core/manifest/test_shell.py:1796` (projects) `` merge-tree's `apply_program_projects` reads each manifest's top-level `program` key and SKIPS any ``
- `evals/lifecycle-manifests/fixtures.sh:141` (PROJECT) `# A repository holding a SMALL REAL PROJECT: source, a test, and a README naming a genuine gap.`
- `evals/lifecycle-manifests/fixtures.sh:152` (project) `_eval_repo_with_project() {`
- `evals/lifecycle-manifests/fixtures.sh:163` (project) `git -C "$dir" commit --quiet -m "real project" >/dev/null 2>&1`
- `lib/desktop.zsh:32` (project) `local project="${topic:-$name}"`
- `lib/desktop.zsh:43` (project) `--arg display_name "$project" \`

- **Resolved by R4, `borg.zsh:3214` (1 row).** The `/borg-plan` help line "Project planning + Collective review" is a planning surface, and Noah's 2026-10-13 vocabulary says planning surfaces (PROJECT_PLAN.md, /borg-plan, /borg-assimilate) keep "project". It is now `workstream` and is no longer listed here.
- **Retired name, no rename (1 row).** `borg_core/manifest/test_shell.py:1796` quotes `apply_program_projects`, a merge-tree function that no longer exists. Suggested: external (a historical name in a docstring).
- **Generic English in eval fixtures (3 rows).** `evals/lifecycle-manifests/fixtures.sh` 141, 152, 163: "a small real project", the helper name `_eval_repo_with_project` and a commit message. They describe a fixture git repo, so repository is likely right for 152 and 141; 163 is a commit message string. Needs a reader.
- **Claude Desktop display name (2 rows).** `lib/desktop.zsh` 32 and 43 build a topic display name for a registry entry that has no repository. Likely repository (a local variable); depends on whether the Desktop concept is a "Project" in Claude's own sense.

## Noise-sense sites (all 48 rows)

48 rows on 48 lines in 11 files, in two cases. Every one is either part of the English word projection or projected, or the verb "to project". A rename script must skip them: editing `projection` to `repositoryion` or "projects it into the prompt" to "repositories it into the prompt" would corrupt prose. The old sense of each row is in its note column. Locations are `file` then line numbers (all at `a2744df`).

- **projection (26 rows; was external 19, ambiguous 6, repository 1).** The noun "projection": a view derived from a larger document, here mostly the jq filter in `borg.zsh` that builds the briefing prompt from the `borg link` document.
  - `borg.zsh` (7): 1382, 1403, 1414, 1475, 1476, 1485, 1514. Line 1414 is the filename `briefing-projection-stderr.log` and line 1485 is a user-visible fallback string ("the document projection produced nothing") that `tests/briefing.bats` asserts.
  - `tests/briefing.bats` (14): 291, 379, 431, 493, 504, 507, 512, 518, 537, 549, 551, 552, 690, 727. Lines 537 and 551 are the mock marker `MOCKED-PROJECTION-FAILURE`.
  - `borg_core/link/grid.py` (1): 925. `borg_core/link/test_grid.py` (2): 2074, 2370.
  - `tests/link_sweep.bats` (2): 45, 160.
- **projected (12 rows; was external 8, repository 4).** The participle, including the variable named `projected`.
  - `borg_core/recon/test_core.py` (4): 377, 378, 379, 380, the local variable `projected` in a contradiction test. These four were repository and are the rows the first draft called English words in an identifier.
  - `borg_core/link/grid.py` (3): 167, 246, 917. `borg_core/manifest/core.py` (1): 726. `borg_core/manifest/test_shell.py` (1): 1365.
  - `tests/briefing.bats` (3): 6, 394, 569.
- **verb "to project" (10 rows; was repository 4, ambiguous 3, external 3).** The `--brief` fold is described as the code that "projects that JSON into the narrative prompt", and the test file and contract file repeat the sentence.
  - `borg.zsh` (3): 1291, 1368, 3684.
  - `borg_core/link/cli.py` (1): 447. `borg_core/link/test_cli.py` (1): 410.
  - `tests/briefing.bats` (2): 16, 330 (the second match on that line). `tests/cli_contract.bats` (2): 3039, 3528.
  - `borg_core/link/test_grid.py` (1): 1449, "The receipt used to project `dropped` away".

Counts by file: `tests/briefing.bats` 19, `borg.zsh` 10, `borg_core/link/grid.py` 4, `borg_core/recon/test_core.py` 4, `borg_core/link/test_grid.py` 3, `tests/cli_contract.bats` 2, `tests/link_sweep.bats` 2, `borg_core/link/cli.py` 1, `borg_core/link/test_cli.py` 1, `borg_core/manifest/core.py` 1, `borg_core/manifest/test_shell.py` 1.

Not noise, kept as classified: `pyproject` (25 rows, external), `projectPath` in `scripts/resume-skeleton.py` (161, 231; external, Claude's own session key), `myproject`, `aproject`, `nosuchproject` (19 rows), `ProjectNotFound` (15 rows), `testprojectdirof...` (2 rows) and the other identifiers that contain the noun as a component.

## Contract-sense breakdown (1061 rows)

A contract name is one that other code, hooks, the plugin or on-disk data read, so renaming it needs a migration or a deprecation path. The table groups the rows by the identifier the match sits inside, derived from the code on each line rather than from the note column. R5 added the scaffold heading to "other identifiers". R4 (#369) adjusted it by hand: 4 `--project` flag rows joined the `projects` row, the `@project_dir` row joined `@project_*`, and the 10 statemigrate module-path rows left "other identifiers" when they went back to repository.

| contract name                         | rows |
|---------------------------------------|------|
| `projects` (key, flag, jq path)       | 586  |
| `project` (field or value, see below) | 173  |
| `PROJECT_PLAN.md` and `PROJECT_PLAN`  | 107  |
| `total_projects` (link --json)        | 55   |
| `.borg-project` marker                | 35   |
| projects.json / `projects_file`       | 28   |
| `items_by_project` (recon doc)        | 17   |
| `@project_*`, `tmux.project_dir`      | 16   |
| env vars (see below)                  | 14   |
| other identifiers embedding a name    | 24   |
| `__PROJECT_NAME__` placeholders       | 6    |
| total                                 | 1061 |

- **The registry key is most of the first row.** 584 rows read `projects`, and the token-level grouping cannot separate the registry key from the `borg link --json` document key and the recon `--projects` flag, which share the spelling. By the shard notes the registry key, its jq paths and its fixtures dominate; the flag is the smaller group.
- **Env vars:** `BORG_WORK_PROJECTS` 10 rows, `BORG_PROJECT_NAME` 4 rows.
- **The `project` rows (166) are wire fields and values:** the recon Item key, the `borg next --json` row key and its chooser fixtures, the `project` field of `token-spend.jsonl` and `cortex-wakes.json` records, the `project` key of resume session and ledger files, the session-mode value `project` returned by `_borg_session_mode`, and `# Project Plan:` heading text inside PROJECT_PLAN.md fixtures.
- **`.borg-project`** (35 rows): the marker filename, written by `drone.zsh`, read by `lib/borg-hooks.sh`, hard-coded in `hooks/bash-guard.sh` and present in the `borg-link` skill's MARKER-WALK block. The directive's third change item says to keep the filename and decide either way in CLAUDE.md.
- **State-root `projects/`**: about 17 rows name the on-disk `projects/<key>/state.json` directory (`lib/borg-hooks.sh`, `borg_core/statemigrate`), counted inside the `projects` row above because the token is the same. It is on-disk data, not a key in a shared file.
- **Template placeholders** (6 rows) can be renamed only together with the files under `templates/` and `drone.zsh`.
- **Debatable contract calls the shards flagged** and that a human should confirm before treating them as frozen: tmux window options `@project_dir`/`@project_name` (internal to tmux but possibly read elsewhere), the `recon --projects` flag and the adapter `projects.json` file (renameable behind a deprecation alias), the `"Project Plan: Delta/Nox"` fixture bodies, and the `project` key in cortex-wakes fixtures (not checked against Cortex's own spelling).

## External-sense breakdown (188 rows)

- `~/.claude/projects` and Claude Code's per-cwd session and memory directories, `claude_project_dir` helpers, the Claude `project_*.md` memory file names: about 110 rows.
- `pyproject` / `pyproject.toml`: about 25 rows.
- R2 added 3 rows (PR #352): the retired zsh function names `_recon_merge_by_project` and `_recon_project_contradictions` quoted in `borg_core/recon/core.py`, and cairn's own phrase "cross-project restatement" in `borg_core/census/core.py`.
- The English-word false positives that shards 5, 8, 9, 10 and 11 filed here ("projection", "projected", and three uses of the verb) are gone: 30 rows moved to `noise`. What is left of that family is `projectPath`, Claude's own session key in `scripts/resume-skeleton.py` (2 rows).
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

- **The sample by inventory sense:** 45 repository, 9 contract, 5 external, 1 workstream, 0 ambiguous. The workstream and ambiguous senses are barely tested by it (1 of 61 rows); the original 45 workstream rows were instead each read for this document (listed above) and the sense holds on each.
- **Corrections: none at the time.** No auditor disagreement was found, so no row was changed by the audits. The three samples are committed as `2026-10-12-project-rename-audit-seed-11.tsv`, `2026-10-12-project-rename-audit-seed-29.tsv` and `2026-10-12-project-rename-audit-seed-47.tsv` in this directory: the 20 sampled inventory rows per seed, no header, the same six columns, with the sense and note as they stood when the audit ran (before the noise pass). The auditors' own picks are not in them. A joined check against the current TSV finds exactly two differences, both in seed 11 (below).
- **Taxonomy remarks the auditors made, agreed on the row and since acted on:** `grid.py:925` ("projection") and `grid.py:167` ("projected") are substring false positives that were filed under `external`, which stretched the definition of that sense. The auditor recommended a `noise` sense for them; this document adds it, and these two rows, both in the seed 11 sample, are among the 48 reclassified rows. The sample files still show them as `external` because they record the audit as it was. Three rows were close calls resolved toward the inventory: `build-specimens.py:80` (workstream, a variable use), `test_core.py:793` (`projects={}` kwarg mirroring the link --json key, contract) and `nextpick/core.py:481` (`"project": row["project"]` wire key, contract). `briefing.bats:269` has "project" inside an invented repo name and is repository.

## Relabels after R1

R1 (PR #350) renamed the repository sense of `project` in `borg_core/link` and then fixed its own wording, and the TSV was relabelled so later rename PRs do not re-litigate those calls. Only the `sense` and `note` columns of 52 rows changed; keys, line numbers and the row count are untouched.

- **Chain manifest, now `workstream` (33 rows).** Where text said "project" for a chain manifest (a file under `.borg/chains` or `.stacks`), R1 now says "chain". 27 rows moved from repository; 6 were already workstream. The note reads "chain manifest: reworded to chain in #350". They are listed in the workstream section above.
- **Contract, judged by R1 (12 rows, were repository).** The `assemble(projects=...)` kwarg mirrors the `--json` `projects` key, so its sites in `borg_core/link/cli.py` (384), `borg_core/link/core.py` (890, 907 twice, 910, 911, 914, 916, 957) and the two comments in `borg_core/link/render.py` (135, 610) are contract. The `e.get("project")` checkpoint record key in `borg_core/link/core.py:444` mirrors a `--json` field.
- **Callee renamed in R2 (7 rows, stay `repository`).** R1 left these because the name belongs to a function R2 renames: `recon_core.merge_by_project` (`borg_core/link/cli.py:234`, `borg_core/link/test_cli.py:1069`), `paths.project_state_read_path` and `paths.project_state_file` (`borg_core/link/shell.py:245`, `borg_core/link/test_shell.py` 190 and 233) and `recon_shell.write_projects_file` (`borg_core/link/test_grid.py` 701 and 713). Their note reads "callee renamed in R2".
- **Not touched.** Rows R1 renamed keep their `repository` label, and so do the few R1 left in prose (`tests/link_sweep.bats` comments, the `ghost-project` fixture name) and `borg_core/manifest/shell.py`, which is outside R1.

## Relabels after R2

R2 (PR #352) renamed the repository sense of `project` in `borg_core` outside `link/`, plus the 7 call sites in `borg_core/link` noted above, and relabelled the rows it judged were not `repository`. Only the `sense` and `note` columns of 42 rows changed (35 relabelled or re-noted, 7 callee notes extended); keys, line numbers and the row count are untouched. Every changed note cites #352.

- **Contract, kept (27 rows, were repository).** `projects_file` in `borg_core/recon/cli.py` (5 rows) names the `projects.json` file handed to adapters; the `project=` kwargs in `borg_core/recon/test_core.py` (5 rows) build an Item wire key; the `migrate-project-state` flag and message prefix in `borg_core/statemigrate/project_cli.py` (6 rows) are a command-surface name; the module paths `project_cli`, `project_core` and `project_shell` in `borg_core/statemigrate/` and their tests (10 rows) are invoked from `borg.zsh`, so renaming them needs an R4 edit; `borg_core/paths.py:102` (1 row) is the file name `tests/project_state.bats`.
- **External, kept (3 rows, were repository).** `_recon_merge_by_project` and `_recon_project_contradictions` in `borg_core/recon/core.py` (253, 293) are retired zsh function names quoted in docstrings; `borg_core/census/core.py:9` is cairn's own phrase "cross-project restatement".
- **Repository, kept for R3 and R4 (3 rows, note extended).** `_borg_project_state_key` and `_borg_project_state_file` quoted in `borg_core/paths.py` (101, 128) are `lib/` shell names that R3 renames; `local project=` quoted in `borg_core/registry/cli.py:9` is `borg.zsh` code that R4 renames.
- **Contract to repository (2 rows).** `def write_projects_file` in `borg_core/recon/shell.py` is the definition of a callee R2 renames (the 7 rows noted "callee renamed in R2" call it), and `core.rank(projects)` in `borg_core/nextpick/test_core.py` is a use of a local that the rename needed. Both were mislabelled contract.
- **Callee rows (7, note extended).** The "callee renamed in R2" rows stay `repository`; their note now cites #352.
- **New matches.** None in `borg_core` outside `link/`: every match on `origin/main` maps to an inventory row by file and line text. The 36 matches in `borg_core/link` that do not map are on lines R1 reworded.

## Relabels after R3

R3 (PR #357) renamed the repository sense of `project` in `lib/` and `hooks/` and relabelled the 5 rows it judged were contract. Only the `sense` and `note` columns of those 5 rows changed; keys, line numbers and the row count are untouched. Every changed note cites #357. As after R1 and R2, the pin stays `a2744df` and a row R3 renamed keeps its `repository` label.

- **Contract, kept (5 rows, were repository).** The session-mode value `project` in `lib/borg-hooks.sh` (86, 100) is persisted by `bin/borg-resume` as the `mode` field of the session registry, so it keeps its name; `PROJECT=` in the marker-walk command in `hooks/bash-guard.sh` (291) must stay byte-identical to `skills/borg-link/SKILL.md` and `tests/bash_guard.bats`; the `<project|sid> [project_dir]` placeholders in `lib/borg/resume-close.sh` (4, 4) quote the usage text in `bin/borg-resume`, which is outside R3. The prose comment at line 17 ("when a repository directory is given") was first kept as contract by mistake; it means a repository directory, so it is reworded and its row is back to `repository`.
- **New matches (42, no row).** The inventory scans only `*.py`, `*.zsh`, `*.sh` and `*.bats`, so the extensionless `lib/recon/adapters/recon-adapter-github` (32 matches) and the `lib/borg/*.sh` lines added after the pin (10 matches) have no row. 17 adapter matches are repository sense and were renamed; the other 25 are contract (the `--projects` flag, `projects.json`, the Item `project` key, the session registry `.project` and `.tmux.project_dir` fields, the tmux `@project_dir` option). The `bin/` scripts have the same gap and no assigned step.

## Relabels after R4

R4 (PR #369) renamed the repository sense of `project` in `borg.zsh`, moved the `borg_core/statemigrate` `project_*` modules to `repository_*`, and made the Queen's tmux window and Claude session names "queen" and "borg-queen". It relabelled 18 rows. Only the `sense` and `note` columns changed; keys, line numbers and the row count are untouched. Every changed note cites #369. As after R1 to R3, the pin stays `a2744df` and a row R4 renamed keeps its `repository` label.

- **Contract, kept (5 rows, were repository).** The `--project` flag name of `borg spend` (the `--project|-p)` arm, the comment quoting it twice, and the help line) stays because command, subcommand and flag names never change (4 rows); the tmux window option `@project_dir` read in `cmd_down` is written by `drone.zsh` and read by `borg-resume` (1 row, one of the debatable calls the contract breakdown flags).
- **Workstream (3 rows).** `PROJECT MANIFEST:` and `a project manifest` in the briefing prompt mean a chain manifest, the workstream sense (2 rows, were repository); `/borg-plan  Project planning + Collective review` is a planning surface and keeps the word (1 row, was ambiguous).
- **Repository again (10 rows, were contract).** R2 labelled the statemigrate module paths `project_cli`, `project_core` and `project_shell` contract because `borg.zsh` invokes them. R4 renamed the modules and their two tests and updated the call site, so those 10 rows (`borg_core/statemigrate/` `project_cli.py` 1, 12, 13; `project_core.py` 3; `project_shell.py` 11; `test_project_core.py` 8, 9, 56; `test_project_shell.py` 1, 12) are `repository` with a note saying so. The `file` column keeps the pinned path.
- **Left as repository on purpose (1 row).** `borg.zsh` `nosuchproject` in a comment about `link --porcelain nosuchproject` is the fixture word the tests pass, so it stays with them.
- **New matches (17, no row).** 13 repository-sense matches on lines added or reworded after the pin (the briefing prompt text, the `borg link [repository]` help and usage lines, the `status` help line, the `_link_project` comments) were renamed; 4 are `projection` (noise: the `projection` variable of the briefing jq). The 81 matches left in `borg.zsh` read repository 1, contract 61, workstream 5 (3 rows and 2 new matches in the `cmd_chain` comment), noise 14.

## Relabels after R5

R5 renames the repository sense of `project` in `drone.zsh` (Part A), then `merge-tree/`, `evals/`, `templates/`, `install.sh` and the closing sweep (Part B). Only the `sense` and `note` columns changed; keys, line numbers and the row count are untouched. Every changed note starts with R5. As after R1 to R4, the pin stays `a2744df` and a row R5 renamed keeps its `repository` label. `drone.zsh` is byte-identical at `a2744df` and at `origin/main`, so every row maps to its line without drift.

- **Part A, `drone.zsh` (3 rows, were repository).** `_compose_project_label` (the callers at `drone.zsh:256` and `drone.zsh:265`, found by the quoted code `name=$(_compose_project_label "$1")`) is the helper that computes docker compose's own `com.docker.compose.project` label, so it keeps docker compose's word and is external (2 rows; its definition at 247 was already external). The `## Local Supabase — ONE shared stack (never boot a per-project stack)` heading in `_scaffold_append_claude_md` is the idempotency key matched with `grep -qF` in CLAUDE.md files already scaffolded into other repositories, so changing it would append a second block on the next scaffold; it is contract (1 row). The other 429 repository rows in `drone.zsh` were renamed.

**Part B** (`merge-tree/`, `evals/`, `templates/`, `install.sh`, the `docs/` code files, the tests that pin them, and the closing sweep; 2026-10-13). Only the `sense` and `note` columns changed again, for 37 rows; keys, line numbers and the row count are untouched, and every changed note starts with `R5:`. A row Part B renamed keeps its `repository` label.

- **Renamed in the scoped areas (151 rows, stay `repository`).** `merge-tree/` 96 (`coordinator.py` 26, `test_coordinator.py` 70), `evals/` 14 (`lifecycle-manifests/run.sh` 9, `session-load/run.sh` 2, and `fixtures.sh` 3 that were ambiguous, below), `templates/` 10 (the eleventh row, `supabase/borg-hooks/pre-up.sh:3`, is Supabase's word and is relabelled below), `install.sh` 11, the `docs/` code files 20 (`docs/infoviz/harness/build-specimens.py` 19, `docs/pr158-rider/prototypes/build_chains.py` 1). The 15 `build-specimens.py` rows that mean a story project (workstream) are untouched.
- **Relabelled and left (31 rows, were repository): contract 28, external 2, noise 1.** Contract: the session-mode value `project`, persisted by `bin/borg-resume` (9: `evals/session-load/run.sh:36`, `tests/lifecycle.bats` 94, 413 and 453, `tests/plan_promote.bats` 5, 6, 7 and 142, `tests/session_mode.bats:6`); the `migrate-project-state` flag quoted in test names and commands (12, `tests/migrate_project_state.bats`, the same call R2 made for the flag in `borg_core/statemigrate`); the `borg spend --project` flag (1, `tests/spend.bats:59`); the `@project_dir` tmux option in a comment (1, `tests/cli_contract.bats`); a test name that quotes the `projects` key of the `--json` document (1, `tests/cli_contract.bats`); the skills' own `<project root>` text that `tests/extension_blocks.bats` greps (3, R6 rewrites the skills); the `<project|sid>` usage of `bin/borg-resume` quoted in `tests/resume_mark_closed.bats:2` (1). External: Supabase's `supabase_network_<project>` in `templates/supabase/borg-hooks/pre-up.sh:3`, and Claude Code's project-scope `.claude/workflows` in `tests/workflow_model_guard.bats:265`. Noise: `tests/briefing.bats:330`, the verb "projects the same document".
- **Ambiguous, all six settled (the suggestions in the section above).** `evals/lifecycle-manifests/fixtures.sh` 141, 152 and 163 to repository: the fixture is a repository holding a small codebase, so the comment is reworded, the helper `_eval_repo_with_project` is now `_eval_repo_with_source` (definition and the 6 callers in `run.sh`) and the commit message reads "real source". `lib/desktop.zsh` 32 and 43 to repository: the local holds a Claude Desktop topic's display name and is now `display_name`. `borg_core/manifest/test_shell.py:1796` to external: a retired merge-tree function quoted in a docstring, like its siblings in R2.
- **Closing sweep (renamed in files outside Part A and the scoped areas, stay `repository`).** Files are listed in the PR body. Fixture words went with their expected text: `myproject` to `myrepo` (`tests/lifecycle.bats`, `tests/state.bats`, `tests/plan_promote.bats`), `nosuchproject` to `nosuchrepository` (`tests/cli_contract.bats:239`, a probe value for a retired flag), and the hyphenated fixture names (`sample-project`, `ghost-project`, `my-active-project`, `quiet-project` and the like) to their `-repository` forms. `tests/project_state.bats` is now `tests/repository_state.bats` (`git mv`); the `file` column keeps the pinned path, and `borg_core/paths.py` names the new file.
- **Kept on purpose (contract, external, workstream, noise), as the sweep read them.** The `projects` registry key, the `--json` keys and the `project` record key (wake, session, recon Item, chooser row), `assemble(projects=...)` and its tests, `projects.json` and the `--projects` adapter flag, `.borg-project`, `PROJECT_PLAN.md` and `# Project Plan:`, the `BORG_*PROJECT*` environment variables, the `@project_dir` and `@project_name` tmux options, `__PROJECT_NAME__`, the on-disk `projects/<key>` state segment, the session-mode value `project`, the `--project` and `--migrate-project-state` names; Claude Code's `~/.claude/projects` and its test stand-ins, Cortex Code's `projects` directory, Supabase's `project_id` and `--project-ref`, docker compose's project label, Claude Desktop's Project; chain-manifest prose that means a body of work (`borg_core/manifest`, `merge-tree/test_s4_manifests.py:55`, `borg_core/link/worktree.py:8`); and the verb "to project".
- **Renamed variables over unchanged strings.** `projects_file` (the path of the `projects.json` file handed to adapters) is now `repositories_file` in `borg_core/recon/cli.py`, `borg_core/recon/shell.py` and `borg_core/link/shell.py`; R2 had kept it as contract, but only the file name and the `--projects` flag are the protocol. In `borg_core/link/test_render.py` the locals that hold the `projects` map are `repositories`; the `projects=` keyword and `total_projects=` stay.
- **New matches (310, no row).** The inventory scans `*.py`, `*.zsh`, `*.sh` and `*.bats` at `a2744df`; 310 matches now sit on lines that were added or reworded after the pin and so map to no row. None is repository sense: contract 265, external 32, noise 10, workstream 3. The extensionless `bin/` scripts (for example `bin/borg-resume`) and `lib/recon/adapters/recon-adapter-github` are still outside the grep and have no step.
- **Whole-tree count after R5 Part B.** `git ls-files "*.py" "*.zsh" "*.sh" "*.bats" | xargs grep -noiE "project(s)?"` gives 1472 matches in 151 files, down from 3911 in 148: repository 0, contract 1161, external 210, workstream 45, noise 56. That closes criterion 2's repository-sense rename for the code files; the extensionless scripts and the markdown (R6) are what is left.

## Known limits

- **The classification is rule-based.** Each shard classifier applied rules to the text around each match and overrode by site. Nobody read all 3911 rows; the repository rows (2605, the edit scope) are the default and are the least checked. 45 of the 60 audited rows were repository and all 45 agreed, which bounds nothing tighter than a spot-check.
- **Substring noise is now settled; verb noise is found by pattern, not by reading.** A mechanical check of the code on each line finds 63 rows where the match still sits inside a longer word: 27 external (`pyproject` 25, `projectPath` 2) and 36 repository (`ProjectNotFound` 15, `myproject` 15, `nosuchproject` 3, `testprojectdirof...` 2, `aproject` 1). They are identifiers that contain the noun as a component and stay. The other 38 such rows were English words and are noise. The verb case has no such mechanical test: the 10 verb rows were found by scanning every row for verb-shaped context (see "Noise pass"), so a verb use in a context that scan does not recognise could still sit in the repository rows. Reclassifying one later is a one-row edit.
- **`--migrate-project-state` is classed inconsistently.** 18 rows on lines that mention the flag or its Python spelling are repository and 1 is contract. It is a CLI flag, so it may need a deprecation alias like the other contract names. Decide once before the rename. R2 (PR #352) decided it: the flag and its `migrate-project-state:` message prefix stay, so those 6 rows in `borg_core/statemigrate/project_cli.py` are now contract.
- **`PROJECT_PLAN.md` is contract by decision of the classifiers**, not the directive. The directive does not mention renaming it; treat the 107 rows as frozen unless that changes.
- **Line numbers drift.** They are exact at `a2744df` only. Use `file` plus the quoted code to relocate a row on a newer tree.

## What this means for the rename PRs

- **`repository` is the edit scope for the next rename PR: 2533 rows,** about two thirds of the occurrences. The other 1378 rows (contract 1061, external 188, workstream 75, noise 48, ambiguous 6) must not be touched by a mechanical pass. The noise rows are the ones a naive word-boundary-free replacement would damage first.
- **Contract names migrate separately,** each behind a reader that accepts both spellings, per the directive: the registry key `projects` last, after every reader tolerates `repositories`. The `--json` document keys (`projects`, `total_projects`, row key `project`) are a wire change for the `borg-link` skill and need a `DOCUMENT_VERSION` decision.
- **`.borg-project` and `PROJECT_PLAN.md` are decisions, not edits,** per the directive's third change item.
- **Resolve the 7 ambiguous rows and the flagged judgment calls first;** they are a few dozen rows and each one changes what a rename script may touch.
