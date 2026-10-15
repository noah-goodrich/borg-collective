# Directive: Context diet for CLAUDE.md and the borg-link skill
*Established: 2026-10-14*
*Shipped: 2026-10-15 — PRs #392, #393, #394, #398, #404, #409, #411, #412 and #416 merged to main*

- Plan-slug: `2026-10-14-context-diet`

Covers https://github.com/noah-goodrich/borg-collective/issues/382 and https://github.com/noah-goodrich/borg-collective/issues/383. Filed as a directive because `PROJECT_PLAN.md` holds another plan; see Promotion Trigger. Tracked end to end in https://github.com/noah-goodrich/borg-collective/issues/407 (both issues as sub-issues, every PR in one checklist).

## Objective

Cut the context every session in this repository pays for. CLAUDE.md drops to 8 KB or less with nothing dropped, a `/borg-link` run costs at most 9 KB in repository scope and at most 42 KB in the Queen view, and a size guard keeps both small.

## Measured baseline (main at e801ddf, 2026-10-14)

The issues were filed against older numbers; these are the ones the criteria are measured from.

| Measure                       | Bytes  |
| ----------------------------- | ------ |
| CLAUDE.md                     | 71,223 |
| `## Key Patterns`             | 38,942 |
| `## Learned`                  | 10,795 |
| `### Files`                   | 6,897  |
| `### Commands`                | 5,712  |
| `### Implemented`             | 3,588  |
| skills/borg-link/SKILL.md     | 29,771 |
| Queen pipe output, pretty     | 41,153 |
| Queen pipe output, `-c`       | 29,753 |
| Queen pipe, `-c` + field trim | 24,599 |
| Repository pipe output        | 610    |

- Per `/borg-link` run, bytes into context (skill files read plus pipe output, checkpoint reads excluded): Queen view 70,924; repository scope 30,381.
- "---" directive titles: not reproduced on today's data (0 of 244 directives, 0 shipped, with and without `--all`; no registered repository has a plan file that opens with frontmatter). The code path is real: `core.heading_title` returns the first line, so a frontmatter-first file is titled `---`. A related live symptom: one directive's title is its opening `>` blockquote line.

## Decisions (Noah, 2026-10-14)

- Moved CLAUDE.md content goes HYBRID: a rule owned by one directory moves verbatim into that directory's CLAUDE.md, which Claude Code loads only when a file there is read; history and reference move verbatim into `docs/agents/`, linked from an index in CLAUDE.md that says when to read each file.
- Drones stop running `/borg-link` at session start. The SessionStart hook already injects the directory's latest checkpoint.
- The Queen pipe gets `-c` and deletes eight project fields the Queen view never reads: `claude_session_id`, `path`, `repo`, `clock_divergence`, `tmux_session`, `source`, `notify_origin`, `last_activity`. A `del()` keeps the Queen arm pass-through.

## Acceptance Criteria

- [x] **AC1: CLAUDE.md is 8,192 bytes or less, and nothing was dropped.** Every non-blank line of CLAUDE.md as of the cut's merge base appears verbatim in the slim CLAUDE.md, a nested CLAUDE.md, or a `docs/agents/` file linked from the slim CLAUDE.md. The only exceptions are the index lines, listed in the PR. The PR body says what moved where.
  - Verify: `wc -c CLAUDE.md`; `git show <base>:CLAUDE.md | grep -v '^$' | sort -u` compared with `comm -23` against the sorted union of every tracked CLAUDE.md plus `docs/agents/*.md` prints only the listed index lines.
  - Evidence 2026-10-15: `wc -c CLAUDE.md` is 6,881 (cap 8,192). The cut merged as https://github.com/noah-goodrich/borg-collective/pull/411 (75,990 to 6,881 bytes; 8 nested CLAUDE.md files plus 8 `docs/agents/` files). The `comm -23` check re-run on main at 7756f9a5 against base `4b42598` prints six lines. Three are the index lines #411 listed (`## Key Patterns`, `## Learned`, and the "Cairn decommission ... under Learned" pointer line). The other three are lines reworded by later merges, not drops: `## Current State (v2, release v0.9.6)` (now v0.9.7, the release bump), the compass paragraph (reworded by #408 in `borg_core/compass/CLAUDE.md`) and the `coco.zsh` Files line (reworded by #418 in `docs/agents/files.md`).
- [x] **AC2: A size guard fails the build when either file grows back.** `tests/context_budget.bats` fails when the top-level CLAUDE.md exceeds 8,192 bytes, any other tracked CLAUDE.md exceeds 12,288 bytes, or `skills/borg-link/SKILL.md` exceeds 8,192 bytes.
  - Verify: `bats tests/context_budget.bats` is green; appending one byte past a ceiling turns it red (mutation run recorded in the PR).
  - Evidence 2026-10-15: `bats tests/context_budget.bats` is green, 6 of 6 cases. Mutation proofs are recorded in https://github.com/noah-goodrich/borg-collective/pull/411 (root CLAUDE.md padded to 8,193 bytes: red; `hooks/CLAUDE.md` padded to 12,289 bytes: red; `docs/agents/files.md` renamed away: red) and https://github.com/noah-goodrich/borg-collective/pull/404 (SKILL.md at 8,201 bytes: red). Each was reverted.
- [x] **AC3: The borg-link SKILL.md is 8,192 bytes or less, and its references reach the installed plugin.** Queen-view detail moves to `skills/borg-link/references/queen-view.md` (read only when `scope.kind == "orchestrator"`), the fallback to `references/fallback.md` (read only on the fallback trigger), and design history to `references/rationale.md` (never read at runtime). `scripts/build-plugin.sh` copies whole skill directories. Both jq arms run with `-c`, and the Queen arm deletes the eight fields above. SKILL.md says drones need not run it at session start.
  - Verify: `wc -c skills/borg-link/SKILL.md`; `scripts/build-plugin.sh --dry-run` lists the references files; `tests/bash_guard.bats`'s marker-walk case reads the walk from its new home; `tests/skill_borg_link.bats` reads the prose from its new home.
  - Evidence 2026-10-15: `wc -c skills/borg-link/SKILL.md` is 8,189 (cap 8,192; was 32,156 before https://github.com/noah-goodrich/borg-collective/pull/404). `skills/borg-link/references/` holds `fallback.md`, `queen-view.md` and `rationale.md`. The build fix shipped earlier as #398 and the drone-start line is in SKILL.md. The marker-walk and prose cases moved with #404 and are green (`tests/skill_borg_link.bats`, `tests/bash_guard.bats`). Mirror check `diff -r` of this repository's `skills/borg-link` against `claude-plugins/borg-collective/skills/borg-link`: the three references files are identical; SKILL.md differs in exactly the two places #416 changed (the repository arm cuts `leg.text` to 200 characters, and one redundant sentence was dropped from "Never render"). The mirror was rebuilt at release 0.9.7 before #416 merged, so the next mirror rebuild carries that change.
- [x] **AC4: Measured cost per `/borg-link` run, before and after, both scopes.** Bytes into context (skill files read plus pipe output): repository scope 30,381 to 9,216 or less; Queen view 70,924 to 43,008 or less. One transcript measurement per scope (input-token delta on the turn after the run) is recorded in the PR, before and after.
  - Verify: `wc -c` over the files each scope reads plus the pipe output from a live `borg link --json`, in the PR body; the transcript deltas next to them.
  - Evidence 2026-10-15, bytes from source (tracking issue https://github.com/noah-goodrich/borg-collective/issues/407): Queen run 8,186 + 11,487 + 21,690 = 41,363 (cap 43,008). Repository run 8,189 + 943 = 9,132 after https://github.com/noah-goodrich/borg-collective/pull/416 (cap 9,216); re-measured at main 7756f9a5 from a checkout of this repository: SKILL.md 8,189 plus the repository arm's pipe output 941 on the live board. Transcript measurement 2026-10-15 on fresh sessions of the installed 0.9.7 plugin: repository scope 5 requests, context 74,019 to 78,859; Queen scope 3 requests, context 71,427 to 88,831. Before (2026-10-14 median over 12 calls): 6 requests at 83k context. The Queen figure was measured before #416, which only touches the repository arm.
- [x] **AC5: Directive and shipped-plan titles never read `---`.** `core.heading_title` skips a leading YAML frontmatter block, then returns the first `#` heading, else the frontmatter `title:` value, else the first non-blank line after the frontmatter.
  - Verify: pytest cases in `borg_core/link/test_core.py` for each branch, including the bare `---` file and today's no-frontmatter files (unchanged); `bin/link-parity-harness primitives` records the frontmatter case as an intended divergence rather than a failure.
  - Evidence 2026-10-15: https://github.com/noah-goodrich/borg-collective/pull/394 merged S1. `python3 -m pytest -q borg_core/link -k heading_title` passes 25 cases (every branch, the bare `---` file and no-frontmatter files unchanged); a real-file `read_directives` case is in `test_shell.py`, and the parity harness records the frontmatter case as an expected deviation.
- [x] **AC6: Nothing breaks.** `make test`, `make test-bats` and `make lint` are green. Every prose-contract test that grepped CLAUDE.md or SKILL.md greps the text's new home and none is deleted. `borg_core/census` scans every tracked CLAUDE.md, not only the top-level one. Code comments that cite "CLAUDE.md's Learned" or another moved section name the new file.
  - Verify: the three make targets; `git grep -n "CLAUDE.md's \"Learned\"\|CLAUDE.md, \"Learned\"\|CLAUDE.md's Learned" -- ':!docs/plans' ':!.borg'` returns nothing (dated checkpoints and plans, this one included, are history and keep their wording); the census pytest covers a nested CLAUDE.md.
  - Evidence 2026-10-15, on main at 7756f9a5 in a fresh worktree: `make test` 2290 passed; `make lint` clean (ruff, mypy, pylint 10.00/10); `make test-bats` 2367 ok and 6 not ok, all environmental (no `.venv` in a fresh worktree): five `tests/eval_floor.bats` cases (693 to 697) and `evals/lifecycle-manifests` (708), the same failures #411 reported; CI is the full-suite evidence. `bats tests/prose_contracts.bats tests/cli_contract.bats` 250 of 250 ok. The `git grep` above returns nothing. Prose-contract repointing and the widened census shipped in https://github.com/noah-goodrich/borg-collective/pull/411 (two nested-CLAUDE.md pytest cases).

## Testability

- AC5 is the only logic change. It lives in the pure core (`borg_core/link/core.py`), tested by pytest on literals, plus the existing real-file case in `test_shell.py`. The parity harness's `primitives` leg compares against `head -1 | sed`, so it gets an explicit expected-divergence entry, not a weakened comparison.
- AC2 is a new bats file, proven by mutation.
- AC3's build change is shell (`scripts/build-plugin.sh` Phase 1). It has no test today; the slice adds a dry-run assertion that a skill subdirectory file is listed.
- `borg_core/census/shell.py`'s `DOCS` change ships with a pytest case for a nested CLAUDE.md.
- AC1, AC3's SKILL.md split and the comment-pointer sweep are docs moves. They are verified by the AC1 line check and the repointed prose-contract tests, not by new logic.

## Slices (one PR each, nanoprobe-built, merged on Noah's word)

| Slice | Content                          | Can start          |
| ----- | -------------------------------- | ------------------ |
| S1    | AC5 heading_title                | now                |
| S2    | AC3 jq `-c` + field trim         | now                |
| S4a   | AC3 build fix                    | merged (#398)      |
| S4b   | AC3 split, AC2 skill guard       | after #386, #397   |
| S5    | AC1, AC2, AC6 CLAUDE.md cut      | after the queue    |
| S6    | AC4 Queen pipe trim              | after S4b          |
| S7    | AC4 collapse finished stacks     | after S6           |
| S8    | AC4 repository arm trims the leg text | now            |

- S3 (drone start) folds into S4b as one SKILL.md line.
- S4 split in two on 2026-10-14: S4a ships the build fix first, so S4b's `references/` files reach the installed plugin.
- S5 waits for every open PR that edits CLAUDE.md to merge (#379, #381, #385, #278, and R6 from the front-door wave 2). The AC1 line check runs against the base after they land.
- S6 was added 2026-10-15 on Noah's word. The Queen pipe output grew from 25,849 bytes after S2 to 38,655 bytes: `compass` (7,502 bytes) arrived with #385 and #397, and `grid` reached 18,658 bytes once every in-flight PR was stacked. So the split alone leaves a Queen run near 58 KB. S6 audits which `grid` and `compass` fields `references/queen-view.md` reads, drops the rest in the Queen arm, adds one bats case per dropped field, and keeps SKILL.md at 8,192 bytes or less.
- S7 was added 2026-10-15 on Noah's word. After S6 (#409) a Queen run measured 49,483 bytes, still about 6.5 KB over. Of the 11 stacks on the board, 10 had every row merged, and their nodes were 11.8 KB of the 14.4 KB `grid`. Finished stacks are also what grows, one row per merged PR. S7 collapses a stack whose rows are all merged or closed to `{id, desc, repos, rows, done: true}` in the Queen arm, and `references/queen-view.md` mentions such a stack in one line at most. Open stacks pass through unchanged. Shipped work still reaches the Queen view through `assimilated`.
- S8 was added 2026-10-15 on Noah's word. The repository arm passed the compass leg text through untrimmed, and the leg text is the owner's prose, so its length is not the skill's to control. After S7 a repository run measured 9,406 bytes against the 9,216 cap. The arm now cuts `leg.text` to 200 characters, so the cap holds on any day.
- AC4's "after" is measured once S4b, S6 and S7 are merged and the plugin mirror is rebuilt.

## Scope Boundaries

- NOT building: size limits for other skills or agents.
- NOT building: the per-worktree duplication of directive aggregates (parked in the map's parking lot 2026-10-14).
- NOT building: rewrites or condensations of moved rules. They move verbatim; editing them is separate work.
- If done early: ship, don't expand.

## Ship Definition

Each slice: PR opened, CI green, `/borg-verify` PASS, Noah's word, squash-merged. After S4b, S6 and S7: the mirror is rebuilt and the plugin updated (the R6 end-of-day step), then AC4's "after" is measured.

## Timeline

Target: S1 and S2 on 2026-10-14; S4b, S5, S6 and S7 once their blocking PRs merge, likely 2026-10-15.
Estimated effort: three sessions (S6 and S7 added one).

## Risks

- Wave 2's R6 vocabulary sweep and the compass PR rewrite CLAUDE.md lines. A cut built before they merge would silently re-add or drop their edits, so S5 starts after them and AC1 runs against the post-merge base.
- A nested CLAUDE.md loads only for reads inside its own directory. Rules that guard `borg.zsh` or `drone.zsh` (repository root) cannot be nested and must stay reachable from the top-level index.
- Until `build-plugin.sh` copies skill subdirectories, a split skill reads `references/` files the installed plugin does not have. The build fix ships in the same PR as the split.

## Promotion Trigger

`PROJECT_PLAN.md` holds `2026-10-06-borg-next-chooser`. This directive is executed in place from `docs/plans/directives/` and is assimilated on its own when AC1 to AC6 are ticked; it does not displace that plan.
