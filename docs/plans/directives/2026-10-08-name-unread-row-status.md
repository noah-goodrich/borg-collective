# Directive: Name the row status words borg does not read as PR state
*Filed: 2026-10-08 · Status: Accepted 2026-10-08 · Owner: Noah*

**tl;dr** — borg reads only `open`, `merged` and `closed` from a row's `status`, so when nothing live answers for a ref, a team stamper's `review` or `stacked` renders like a row that declared nothing, and the page never says a word was dropped. One PR, sharing no file with #276, names those words in `▸ SIGNALS`, fixes the detail line that calls them "not declared" and stops reconcile calling them stale; option C, reader side first, is the accepted next step.

- Plan-slug: `2026-10-08-name-unread-row-status`

## Problem

Cites are main at `b34e7e0`.

- **Three words pass; the rest vanish.** `DECLARABLE_STATES` is `open`, `merged`, `closed` (`borg_core/link/grid.py:71-78`). The declared rung returns `unknown`/`unknown` for any other word, with no warning (`grid.py:303-306`), and nodes carry no `status` key (`grid.py:788-815`).
- **The page then says something false.** With no live answer (`--local`, a failed fetch, or a non-GitHub ref the fetch skips by design, `grid.py:394-407`), the detail block says "nobody has an answer for this ref (not swept, not fetched, not declared)" (`borg_core/link/picture.py:385`).
- **The words are deliberate.** A team stamper prints `status` verbatim into a human-facing table, in its own vocabulary: `merged`, `approved`, `review`, `stacked`, free text. With no live answer, main's `resolve_state` returns `unknown` for 14 of 38 rows in an employer-side repo's `.stacks/` and 4 of 9 in another private repo's (run 2026-10-08). #276, merged 2026-10-08, is what makes borg read `.stacks/`.
- **reconcile disagrees with grid.** It compares the raw string (`borg_core/reconcile/core.py:82-83`), so a correct `review` on an open PR, and `Merged` on a merged one, come out `stale_declared`. Its first planned caller, the trains publish check, refuses on any finding (`docs/plans/directives/2026-10-04-personal-pr-stack-stamper.md:60`).
- **Why it matters:** once #276 lands and those files reach a registered checkout, 18 of the 47 measured rows render under `--local`, which the borg-switch skill uses to list projects (`skills/borg-switch/SKILL.md:9`), exactly like rows that declared nothing.

## Decision

Accepted 2026-10-08. Step 1, this PR, ships the directive and the code below together. The accepted next step is option C, reader side first: a `label:` detail line quoting `status`, only the three words read as state. A is rejected; B stays Noah's call and depends on the first open question.

## Solution

Step 1, this PR: one PR from a worktree off main. It touches none of the nine files #276 touches and changes no node state, edge or READY membership (`ready_refs`, `grid.py:819-852`).

1. **One aggregate SIGNALS line** from `build_grid` (`grid.py:944-1000`), over the rows `_grid_nodes` already walks (`grid.py:784-788`). A row counts when it declared a non-blank `status` yet ended at `state_source` `unknown`, which a declared `merged` never does, so the count needs no second copy of the three words. The line quotes up to three words with counts, flattened by `link.core.flatten_summary` (`borg_core/link/core.py:816`), for example `declared: 3 row(s) carry a word that is not a PR state ("review" x2, "stacked" x1) -- shown unresolved`.
   - It rides `grid.warnings`, so it prints before the resolution line (`render.py:1073`, then `:1078`) and adds no wire key.
   - It must not contain `unknown`, `nobody has an answer for this ref` or `declared refs unresolved`, which `tests/cli_contract.bats:3299-3304` counts. Its prefix avoids `status`, which already names session status (`borg_core/link/core.py:37-38`).
   - A render whose sweep or fetch answered every such ref prints nothing.
2. **`picture.py:385`** becomes "nobody has an answer for this ref (not swept, not fetched, no PR state declared)", true for a row with no `status` and for one with a word borg does not read. The four distinct sentences stay four (`borg_core/link/test_picture.py:483`).
3. **reconcile reads the same three words.** `row_finding` lowercases the declared value and compares only `open`, `merged`, `closed`; any other word is no claim. The words sit as a literal beside `RESOLVED_SOURCES` (`reconcile/core.py:30-35`), because the core may import nothing (`borg_core/reconcile/test_core.py:38`), and a test pins the copy equal to `grid.DECLARABLE_STATES`.
4. **A fixture row and the missing pin.** One row of `tests/fixtures/link/manifests/auth-hardening.json` declares `review`. Both grid goldens resolve that row, so they stay byte-identical; `--local` does not, so a new contract case sees the line. Add `test_the_last_word_on_a_local_page_is_that_nobody_looked`, which `render.py:1075-1076` cites and no file defines.
5. **Docs.** `merge-tree/SCHEMA.md` gains a `### rows[].status` section below `:259-261`, so no line that `borg_core/manifest/test_core.py:772` or #276's `borg_core/manifest/core.py` cites moves, and drops `stacked` from its example (`:214`). Six comments still say the live viz manifest carries `stacked` (first at `grid.py:73-74`), false since 18af505 (2026-08-31); fix them and three drifted cites (`grid.py:72`, `:476`; `picture.py:296`).

## Acceptance criteria

- [ ] SIGNALS names the unread words once, and only when nothing live answered.
  - Verify: `python3 -m pytest borg_core/link/test_grid.py -q -k unread_status` passes: one line for several rows, words quoted with counts and capped at three, nothing when the sweep or fetch answers the ref, nothing for `MERGED` or a blank `status`, no `unknown` in the text.
- [ ] The `--local` page shows the line, and its last word is pinned.
  - Verify: `bats tests/cli_contract.bats -f 'link --local'` passes, with a new case finding one line naming `"review"` above `declared refs unresolved`, and the case at `tests/cli_contract.bats:3292-3305` unedited. `python3 -m pytest borg_core/link/test_render.py -q -k last_word_on_a_local_page` passes.
- [ ] The detail line stops claiming "not declared".
  - Verify: `rg -n "not declared" borg_core/link/picture.py` prints nothing, and `python3 -m pytest borg_core/link/test_picture.py -q` passes with `:464-493` unedited.
- [ ] reconcile flags only a disagreement in the three words.
  - Verify: `python3 -m pytest borg_core/reconcile -q` passes, with new cases: `Merged` on a merged ref and `review` on an open ref yield no finding, `open` on a merged ref stays `stale_declared`, and the literal equals `grid.DECLARABLE_STATES`.
- [ ] Regression: nothing pinned moves, and nothing is shared with #276.
  - Verify: CI is green (`make lint`, `make test`, `bats tests/*.bats`). `git diff --quiet main...HEAD -- 'tests/fixtures/link/*.golden' 'tests/fixtures/link/*.expected' tests/link_sweep.bats` exits 0. The asserts at `test_grid.py:441-445` and `DOCUMENT_VERSION = 2` (`borg_core/link/core.py:52`) are unchanged. `git diff --name-only main...HEAD | grep -Fxf <(git diff --name-only main...origin/feat/manifest-stacks-dir)` prints nothing.

## Non-Goals

- Not building C in this PR. Step 1 holds under A, B and C alike; C's reader half is the accepted next step.
- Not showing the word on swept or fetched renders (`grid.py:788-815`). C's `label:` line is the accepted follow-up.
- Not changing what borg writes into `status` (`borg_core/manifest/cli.py:291-292`, `:319-322`, `:348`, `:499-500`).
- Not rewording the two warnings that say states fall back to what the manifest declares (`borg_core/link/cli.py:178`, a #276 file; `grid.py:554-557`). The new line sits beside them.

## Alternatives Considered

- **A: widen `DECLARABLE_STATES`.** Rejected.
  - It reverses d9f6136's pinned ruling (2026-08-25, `grid.py:71-77`) and turns 8 cases red, one of them the AC3 control written to fail on exactly this widening (`tests/link_sweep.bats:339-340`).
  - It puts the word nowhere new on the page: swept and fetched tokens win (`grid.py:295-302`), and a declared state prints no heading (`picture.py:365-366`).
  - It would print an adapter's swept `review` as a `REVIEW` heading (`picture.py:350-354`, `:368-371`).
  - It has no contract phase, because dropping a word later breaks the files that rely on it.
  - Its strongest form, reading each word as the `open` it implies, is the fallback only if the first open question rules out B and a stamper-side C.
- **B: the stamper narrows to three words.** Not borg's call. It costs borg nothing and moves no pin, and it costs the stamper's table its words on 14 of 38 rows. Whether borg may ask for it at all is the first open question.
- **C: two fields, a state borg checks and a label it passes through.** Accepted next, reader half first: a `label:` detail line quoting `status` on every render, only the three words read as state, READY and `DOCUMENT_VERSION` untouched, no file shared with #276. It follows the `draft` precedent, a refinement of `open` kept in its own node field (`grid.py:809-814`). A stored second field, `declared_state` (6-8 hours, strictly after #276), waits on the second open question.
- **Wait until the vocabulary is settled (worktree directive Q4).** Rejected: #276 wires `.stacks/` in now, and 18 measured rows go silent the day both land.
- **A louder line, per row or on every render.** Rejected: per-row lines teach the reader to skip the section (`grid.py:397-398`), and a healthy fetch answers every GitHub row, so an ungated line would name 14 correctly rendered rows on every page of that employer-side repo.

## Ship definition

A worktree off main, then the PR, then CI green, then a `STACK-APPROVAL: <machine> APPROVES #<n> @ <head-sha>` comment at the current head, then merge. One session of about 3 hours plus one stamp round trip. #276 merged first, so this lands on top of it.

## Risks

- **The line can move a pinned count.** The `--local` contract case counts the three strings named in Solution step 1 (`tests/cli_contract.bats:3299-3304`), which is why the second criterion keeps that case unedited.
- **reconcile goes quiet on a stale word.** `stacked` on a merged PR stops being a finding, and stale words are the measured failure (one employer-side status sat stale for 41 days). Today the same check fires on every correct word too.
- **Two copies of three words can drift.** The equality test in the fourth criterion is the guard.

## Found, separate fix

- **Directive titles render `---` when a file opens with YAML frontmatter.** `heading_title` returns the first line (`borg_core/link/core.py:401-402`), and `borg next` reads titles through a zsh twin that does the same (`borg.zsh:145`, called at `:880`). 55 directive files across 5 registered projects open with frontmatter (measured 2026-10-08); this repo has none.
- **The prefer-tool bypass log moved and two docs did not.** The hook writes `${XDG_STATE_HOME:-~/.local/state}/borg/prefer-tool.jsonl` (`hooks/borg-prefer-tool-log.sh:24`), as State Hygiene's AC4 rule requires for borg-only operational files (`docs/state-census.md:107-111`, `:131`, pinned by `tests/state_writers.bats:62-63`), while `docs/extensions.md:125-126` and `CLAUDE.md:474-475` still name `~/.config/borg/prefer-tool.jsonl`. The docs are the stale side.

## Open questions

Still questions, not rulings. None blocks step 1 or the accepted reader-side C.

1. **Does the one-way shim rule cover a shared data format?** It names two sockets, an executable adapter and a prose extension, and one direction: borg reaches down, the employer plugin never reaches up (`CLAUDE.md:428-443`). A `.stacks/` file that a team stamper and borg both read, and that #276 lets borg write, is neither socket. If the rule covers it, B and a stamper-side C both change the employer's format for borg and drop out.
   - Pointing that way: two systems kept separate on purpose, "not a shared file" (`docs/plans/assimilated/2026-08-18-program-manifests-as-borg-edge-source.md:26`, `:40`); a borg contract independent of "any other tool's file format" (`merge-tree/SCHEMA.md:194-195`).
   - Pointing the other way: one authoritative copy that borg reads "via an adapter, not keep a copy" (`docs/plans/directives/2026-09-28-worktree-identity-and-apex-stacks.md:234-236`), though #276 reads `.stacks/` directly; and rows a team stamper writes already carry borg's `ref` key so borg's validator accepts them.
2. **Does shim §4's "never two writers on one artifact" (shim directive `:83`) bind #276's `add-row` and `close`, which write `status` into `.stacks/`?** If it does, borg's state moves to `declared_state` after #276 merges.
3. **Does this settle worktree directive Q4,** "settle the vocabulary (§3) before wiring" (`:219`)?
