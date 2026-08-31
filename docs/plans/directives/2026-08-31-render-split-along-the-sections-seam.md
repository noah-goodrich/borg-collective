# Directive: Split `render.py` along the seam that already exists
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: 2026-08-16-link-port-latent-defects (assimilated 2026-08-31)*
*Filed: 2026-08-31*

**tl;dr** — `render.py` carries a module-level `# pylint: disable=too-many-lines` added in PR
[#176](https://github.com/noah-goodrich/borg-collective/pull/176). The disable is a deferral with its measurement
recorded (54% of the file's bytes are docstrings, so C0302 measures the design record rather than the code) — and
the fix it defers is a split along a seam the module has already grown: the `SECTIONS` spine and its section builders
on one side, the shared text primitives on the other.

## Why this exists

**The disable is not a verdict and its own comment says so.** Verbatim from `render.py`:

> THIS IS A DEFERRAL, NOT A VERDICT. The real fix is splitting the module along the seam that already exists — the
> SECTIONS spine and its section builders on one side, the shared text primitives (`_fold_s`, `_flatten_summary`,
> `_label`, `_summary_block`) on the other. That is an architecture change and was deliberately not made inside a
> merge fix; it is filed as its own directive.

This is that directive. Filing it is the point: a `# pylint: disable` with a promise in the comment is exactly the
shape of work that disappears, because the linter is now green and nothing else ever asks.

**The measurement, as recorded and re-derivable.** `wc -l borg_core/link/render.py` is 1129 across 39 functions
holding 380 statements, and 34.5k of the file's 64.4k bytes are docstrings. So the ~500 lines of executable code sit
well inside what C0302 targets, which is why suppressing it was the right call in a merge fix and why *cutting prose
to satisfy a line count* was explicitly refused: every paragraph above the disable exists to stop a specific wrong
answer being re-derived — the porcelain/picker retraction, the enumerated scrub set, the per-call-site honesty about
`_flatten_summary`.

**The seam is real, not proposed.** Reading the module's own function order, it already separates cleanly:

- **Text primitives** — `_flatten_summary`, `_label`, `_fold_s`, `_summary_block`, `_objective_lines`,
  `_checkpoint_head_block`, `_placeholder`, `_plural`, `_section`.
- **The page** — `_header_section`, `_focus_section`, `_board_section`, `_grid_section`, `_next_section`,
  `_queued_section`, `_shipped_section`, `_signals_section`, the `SECTIONS` tuple, and `document()`.

The primitives are pure string functions with no knowledge of the document shape. The section builders all have the
same signature (`dict -> tuple[str, list[str]]`) and are already addressed by name from one module-level tuple. That
is a module boundary that arrived on its own.

**Why this is worth doing beyond the lint count.** Two of AC1's five latent defects
(`_summary_block`'s newline handling and `_overview_summary_cut`'s) were the *same defect in the same primitive layer*
found separately, because the primitives are scattered among the section builders that call them rather than sitting
together where a reader would compare them. See `2026-08-31-flatten-the-summary-once-at-assembly.md`, which is the
same observation from the other end.

## Solution

Split into two modules, with `render.py` keeping the page and the public name.

- **`borg_core/link/text.py`** (or `_text.py`) takes the primitives listed above, with their docstrings, verbatim.
- **`render.py`** keeps `SECTIONS`, `document()` and every `_*_section` builder, and imports the primitives.
- **The move is mechanical and must be verifiable as such.** No function body changes, no docstring is rewritten to
  fit its new home, no signature moves. A reviewer should be able to confirm the diff is a relocation.
- **The new module goes on `pyproject.toml`'s clean-arch Domain list in the same commit**, and gets its own AST
  import-walk test. Both are non-optional: the checker returns early on a file it cannot classify, which is precisely
  how `render.py` itself sat unenforced while `make lint` printed 10.00/10 until 2026-08-28.
- **The `# pylint: disable=too-many-lines` comes off**, and if either half still trips C0302 the split was not the
  fix and that is the finding.

## Non-goals

- **Cutting docstrings.** Refused once already, on the record, and the reasoning stands: the prose is the design
  record and trading it for a metric is the failure this repo files under "a check pointed at the wrong thing does
  not fail, it reads as a pass". If the split does not clear C0302 honestly, keep the disable and say so.
- **Changing any rendered byte.** Both grid goldens, all fixture goldens, and the two hand-authored `.expected`
  oracles must be untouched. A golden that moves means the "mechanical relocation" claim is false.
- **Touching `picture.py`.** Its purity contract and its hand-authored oracles are independent of this and must not
  be disturbed.
- **Reorganising the section builders among themselves**, or changing `SECTIONS` order. That is AC2's spine and it
  has its own test.
- **Introducing a package (`render/__init__.py` + submodules).** Two flat modules is fewer moving parts; a package
  would change every import path in the tree for no gain.

## Alternatives considered

**Leave the disable.** Genuinely defensible on today's numbers — the code is not complex, the prose is load-bearing,
and the disable is honest and annotated. Rejected because the file grows every time the page gains a section: it went
from 1133 to 1108 to 1129 within a single week's work, and the next AC adds another builder plus its paragraph. The
seam is cheapest to cut now, while it is still obvious.

**Raise `max-module-lines` in `pyproject.toml` instead.** Rejected — that is the same deferral applied to every module
in the repo at once, including ones where C0302 would be telling the truth.

**Split by section instead (one module per `▸` heading).** Rejected: eight modules that each import the same five
primitives, and the `SECTIONS` tuple would then import eight modules to build one page. It multiplies the import
graph to reduce a line count, and it puts the spine — the one thing AC2 made unbranching — behind eight files.

**Move the primitives into `core.py`.** Rejected: `core.py` is the registry/plan/checkpoint reader. `_fold_s` and
friends are presentation, and the clean-arch classification would have to be argued rather than inherited.

## Acceptance criteria

- [ ] `_fold_s`, `_flatten_summary`, `_label` and `_summary_block` live in one new module with their docstrings
      intact; `render.py` imports them and keeps `SECTIONS`, `document()` and every `_*_section` builder.
- [ ] `grep -c 'pylint: disable=too-many-lines' borg_core/link/render.py` is 0, and `make lint` exits 0 — checked by
      **exit code**, never by grepping the score line, because pylint rounds to 10.00/10 and still exits 4 on one
      warning (that mistake shipped in two commit messages here on 2026-08-28).
- [ ] The new module is in `pyproject.toml`'s `[tool.clean-arch.module_map]` Domain list, verified by probe: a file
      of that name importing `os` and `subprocess` produces W9004 and a non-zero pylint exit. An unclassified module
      is silently unenforced and that has happened in this exact directory.
- [ ] The new module has an AST import-walk test mirroring `test_picture.py`'s P20 and
      `test_render.py::test_render_imports_no_impure_module`. W9004's allow-list permits `pathlib`, `json` and
      `datetime`, so the linter is the coarser of the two gates and neither replaces the other.
- [ ] `git diff --stat` shows no change to any `.golden` or `.expected` file, and `bats tests/` exits 0.
- [ ] `make test` exits 0 with no test deleted — the primitives' existing suites (`TestFoldS`, `TestSummaryBlock`,
      `TestOverviewSummaryCut`, the `_flatten_summary` cases) move with them rather than being rewritten.
