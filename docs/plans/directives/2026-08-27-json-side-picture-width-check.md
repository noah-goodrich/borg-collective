# Directive: A `--json`-side width check so a manifest cannot silently blow `PICTURE_BUDGET`
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: 2026-08-26-ac2-topological-grid-renderer*
*Filed: 2026-08-27*

**tl;dr** — `PICTURE_BUDGET = 68` is a compile-time constant asserted against two fixture manifests and measured
against one golden. A manifest whose short refs run long in three columns exceeds it, and nothing notices until a human
sees a wrapped picture in a 70-column fzf pane. Add a check on the `--json` side, where impurity is allowed.

## Why this exists

Filed verbatim from AC2's own §8 residual-risk section, which states the boundary honestly:

> `PICTURE_BUDGET = 68` is asserted against two fixture manifests and measured against one golden. A future manifest
> whose short refs run long in three columns exceeds it, and nothing in this commit notices until someone authors one
> [...] the picture's width is a compile-time constant because `render.py` is unconditionally pure, and the guard is a
> measurement over the shapes that exist today, not a proof over the shapes that could.

The measured headroom is real, and it is headroom over *today's* manifests, not a bound:

| manifest | widest picture row |
|---|---|
| `link-grid-orchestrator.golden` | 61 columns |
| `link-grid-repository.golden` | 61 |
| live `ingle-t1-cutover` | 46 |
| live `viz-program` | 30 |
| **budget** | **68** |

> **AMENDED 2026-08-28, when built.** Two rows of the original table were stale by the time this was implemented.
> The filed figure of 65 for the fixtures re-measures at 61 (AC4's fixture and glyph changes moved it), so the
> headroom is 7 columns rather than 3. And the fzf preview pane row is gone entirely: the pane was retired the day
> after this was filed by `2026-08-27-retire-unused-link-surfaces.md`, and `grep -c -- '--preview-window' borg.zsh`
> is now 0. `PICTURE_BUDGET` stands on its own; there is no second number to check it against. Re-measure with
> B15's own scan (`tests/cli_contract.bats`, "the widest picture row fits PICTURE_BUDGET and no preview-window
> flag survives" — renamed 2026-08-28 from a title that still promised a pane comparison) rather than trusting
> this table.

Case B15 measures the widest golden row against `PICTURE_BUDGET`. P22 asserts both fixture manifests fit. Both are
guards over authored fixtures. Neither sees a manifest a user writes tomorrow.

The failure mode is not a crash. It is a picture that wraps in the reader's terminal, turning a topology into visual
noise at exactly the moment it is meant to be scanned. (As filed this said "wraps in the fzf preview — the
per-keypress hot path". That pane was retired 2026-08-27; the wrap is still the failure, it just happens wherever the
page is read.)

## Solution

Emit the computed width on the `--json` side and check it there.

- `render.py` and `picture.py` stay **unconditionally pure**. That is load-bearing: it is what lets
  `picture-fork.expected` and `picture-crossing.expected` be hand-authored oracles that do not come from the
  implementation they check. The check does not go in either module.
- `cli.py` (already the impure boundary — it owns `BrokenPipeError` for the same reason) computes the widest row and
  surfaces it. Two candidate shapes, to be decided when built:
  1. a `grid.picture_width` integer on the document, which `--json` consumers and a bats case can both assert against
     `PICTURE_BUDGET`; or
  2. a `▸ SIGNALS` warning when the measured width exceeds the budget, so the human sees *why* the page looks wrong
     instead of just seeing it wrong.

Shape (1) is testable without a human; shape (2) is honest at the moment of failure. They are not exclusive.

## Non-goals

- Making the budget dynamic from `$COLUMNS`. The picture is byte-compared in goldens; a terminal-dependent width makes
  every golden non-reproducible, which is the failure `--local` and the fixture harness exist to prevent.
- Truncating or eliding a too-wide picture. Deciding what to drop is a design question, not a guard.
- Raising `PICTURE_BUDGET`. 68 against a 70-column pane is the arithmetic; the pane is the constraint.

## Alternatives considered

**Assert the budget inside `picture.py`.** Rejected — it would either raise on a real user manifest, taking out the
page for a width problem, or need a logging side effect; and either one ends the purity that makes the hand-authored
oracles meaningful. (As filed, the parenthetical named the fzf preview and `drone status` as "the two paths that
swallow failure silently". Both were retired 2026-08-27. The rejection does not rest on them: raising inside a pure
renderer is the objection.)

**Add more fixture manifests.** Rejected as the primary fix: it widens the sample, it does not bound the shape. Worth
doing anyway as a cheap complement.

## Acceptance criteria

- [x] The widest picture row is computed on the `--json`/`cli.py` side and is observable without reading ANSI output.

  `picture.max_row_width` (pure) is called once in `cli._grid` and stamped as `grid.picture_width`, nested rather
  than top-level because `skills/borg-link/SKILL.md`'s `jq` whitelist selects `grid` wholesale and would silently
  drop a top-level key.

  > **RE-DERIVED 2026-08-28 AFTER REVIEW. This was ticked on a test that could not see the stamp at all.** The
  > evidence originally cited — `test_cli.py::test_json_publishes_the_measured_picture_width_on_the_grid_block` —
  > wrote an EMPTY registry and asserted `picture_width == 0`, i.e. it supplied the condition that makes the derived
  > value equal its own default. A reviewer replaced `picture.max_row_width(block["manifests"])` with the literal
  > `0` and measured `make test` at 925 passed / exit 0 and `bats tests/` at exit 0. That is verbatim the `borg recon`
  > failure in CLAUDE.md's Learned section, on the AC that filed it.
  >
  > The tick now stands on two cases that derive the number from a document that HAS a picture, and never write it
  > down: the pytest case registers a repository carrying the shipped `warehouse-rollout.json` and asserts
  > `grid.picture_width == picture.max_row_width(doc["grid"]["manifests"]) > 0`; `tests/cli_contract.bats`'s B15b
  > ("grid.picture_width is the width of the widest picture row the same run rendered") derives it a SECOND,
  > independent way — scanning the ANSI page the same invocation printed — and compares the two. Both mutations
  > (`= 0`, and deleting the stamp) were applied and confirmed red in both gates.

- [x] A pytest case builds a manifest that exceeds `PICTURE_BUDGET` and asserts the check fires; the mutation that
      turns it red is deleting the check.

  Two cases, one per half. `test_picture.py::test_a_manifest_whose_refs_run_long_in_three_columns_exceeds_the_budget`
  builds the over-budget shape (three children of one parent, 14-character short refs → 71 columns, pinned at 71 so
  a pitch change is reviewable) and also asserts the shapes that exist today still fit, so measuring `len()` instead
  of `visible_len()` goes red rather than merely conservative.
  `test_render.py::test_signals_says_the_picture_blew_its_budget_rather_than_just_looking_wrong` covers deleting
  `_width_line` from `_signals_section`.

  > **CORRECTED 2026-08-28.** That last sentence used to read "*and* deleting the `cli._grid` stamp". False, and
  > checked by mutation: deleting `cli.py`'s stamp line leaves `pytest borg_core/link/test_render.py` **entirely
  > green** — that module is blind to the stamp, because the case sets `doc["grid"]["picture_width"]` by hand and
  > never calls `cli`. Only `test_cli.py` catches it. The pass COUNT is deliberately not recorded: it moves every
  > time a case is added, and a stale count reads as a measurement. The stamp is pinned by the two cases named in
  > the AC above. The test's own docstring carried the same false claim and is corrected in the same diff.

- [x] `picture.py` and `render.py` import nothing new — verified by the clean-architecture linter, not by eye.

  **This one was not satisfiable as filed and required a fix.** `picture.py` was enforced; `render.py` was not
  classified by the linter at all (absent from `pyproject.toml`'s `[tool.clean-arch.module_map]`, and the checker
  returns early on an unclassified file), so it had zero import enforcement while `make lint` printed 10.00/10.
  `render.py` is now on the Domain list — verified by probe: a file named `render.py` importing `os` and
  `subprocess` produces two W9004s and pylint exit 4, where before the change it produced none. Because W9004's
  allow-list already permits `pathlib`, `json` and `datetime`, `test_render.py::test_render_imports_no_impure_module`
  adds the AST walk that mirrors `test_picture.py`'s P20. Neither gate replaces the other.

- [x] `PICTURE_BUDGET` is still `68`, and B15 still asserts the golden against it with no second number.

  **Restated: the second clause as filed named a line that no longer exists.** `borg.zsh:267` is
  `--with-nth 1,3,5`; the fzf preview and its `--preview-window right:70:wrap` were retired on 2026-08-27 and B15
  already asserts their absence. `PICTURE_BUDGET` is unchanged at 68, and this change does not raise it (a
  non-goal).
