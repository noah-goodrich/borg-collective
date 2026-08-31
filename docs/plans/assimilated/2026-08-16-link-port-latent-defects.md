# Directive: Five Latent Defects From the `borg link` Python Port, Filed Late

*Filed: 2026-08-16*
*Shipped: 2026-08-28 — PR [#176](https://github.com/noah-goodrich/borg-collective/pull/176), AC1–AC5, merged to
main*

> **ASSIMILATION NOTE (2026-08-31).** All five ACs ticked with a decision, evidence and a named mutation each; AC1
> additionally shipped a scope correction (the BOARD's `_overview_summary_cut` had the same defect as the deep dive's
> `_summary_block`) and AC2's verify clause was narrowed to its intent rather than waived, with the reading recorded
> inline. Two things the same PR deferred rather than absorbed, both now filed:
> `docs/plans/directives/2026-08-31-render-split-along-the-sections-seam.md` (the module-level
> `# pylint: disable=too-many-lines` it added) and
> `docs/plans/directives/2026-08-31-flatten-the-summary-once-at-assembly.md` (the flatten is opt-in at each call
> site, which is why the same bug had to be found and fixed three times in one day).

## Why this exists

The ship review at the end of the `borg link` Python port
(`docs/plans/assimilated/2026-08-12-port-borg-link-to-the-python-core.md`, PR
[#143](https://github.com/noah-goodrich/borg-collective/pull/143)) recommended six follow-ups. One —
the deployed-artifact drift check — was filed same-day as
`docs/plans/directives/2026-08-14-deployed-artifact-drift-check.md`. The other five were written down
only in `.borg/checkpoints/2026-08-14-1319.md`, which nothing programmatically reads: no test, no CI
job, no `borg doctor` check consumes a checkpoint. They sat there for two days as prose only a human
re-reading that specific file would ever see.

That is the point of filing this directive, not just its contents. These five findings are
individually small — none of them has bitten yet, all are latent contract violations rather than
observed bugs — and it would have been easy to decide none was worth a directive of its own. But
"small enough to skip filing" is exactly how known-but-undone work disappears: a checkpoint is a
session's memory, not a work queue, and the two things must not be conflated. Filing them together,
as one directive with five small ACs, keeps the cost of tracking proportional to the size of the
findings while still making them show up wherever directives already show up (`borg link`, `borg
doctor`, `docs/plans/directives/`).

Every citation below was re-verified against the current source in this worktree (base `41d73d3`) on
2026-08-16, after PR [#153](https://github.com/noah-goodrich/borg-collective/pull/153) refactored
several of these files — line numbers in the original checkpoint had already moved, and one file path
in the checkpoint (`borg_core/link/summarize.py`) never existed; the real file is top-level
`summarize.py`, which the port left in zsh's orbit rather than moving into `borg_core/link/`. All five
are still live.

## Verified findings

- **F1 — Newline normalization gap in the LLM summary path.** `summarize.py:271-272`
  (`summarize_llm`) returns `result.stdout.strip()[:500]` verbatim — `.strip()` only trims leading and
  trailing whitespace, it does not touch embedded newlines. The heuristic path in the same file
  defensively strips internal newlines at `summarize.py:156` and `summarize.py:171`
  (`step[:200].replace("\n", " ")` / `sentences[-1][:200].replace("\n", " ")`). A summary written by
  the LLM path with an embedded newline reaches storage un-normalized. `_summary_block`
  (`borg_core/link/render.py:98-112`) folds every summary through `_fold_s` and re-indents lines 2..n
  to two spaces — but only the lines `_fold_s` itself produces by width-wrapping. A literal `\n`
  already inside the string produces a sub-line `_fold_s` never indents, breaking the `^  [^ ]`
  contract the deep-dive renderer depends on. Latent: one live LLM summary in the registry today, zero
  known to contain a newline.
- **F2 — `borg_core/link/cli.py`'s exception-boundary docstring makes a wrong factual claim.**
  `cli.py:174-190` (the `main()` docstring), specifically line 187: "a narrow `except (ValueError,
  OSError)` on the `--json` path left every entry-shape violation ... to fall through as a raw
  traceback **on stdout** — verified live before this fix." An uncaught Python exception always writes
  its traceback to stderr and leaves stdout untouched; that was true before PR
  [#141](https://github.com/noah-goodrich/borg-collective/pull/141) and remains true after. stdout was
  empty and the exit code was 1 in both cases — only the *stderr text* changed, from a raw traceback to
  the formatted `_die_json` message. The docstring's underlying justification for the broad `except
  Exception` (line 199) is still correct; only its factual claim about which stream leaked is wrong.
- **F3 — `shell._read_text`'s CR-preservation contract is asserted but untested.**
  `borg_core/link/core.py:287-295` (`heading_title`) documents, in its docstring, "A trailing `\r`
  from a CRLF file is preserved, exactly as sed leaves it" — a deliberate fidelity claim distinguishing
  `text.split("\n", 1)` from `str.splitlines()`. But the only caller that reads real files,
  `shell._read_text` (`borg_core/link/shell.py:101-110`), calls `path.read_text(encoding="utf-8",
  errors="replace")`, which uses Python's universal-newlines translation and silently converts
  `\r\n` to `\n` before `heading_title` ever sees the text — defeating the fidelity the docstring
  asserts. The existing test, `test_heading_title` (`borg_core/link/test_core.py:319-323`), passes the
  literal `"# Title\r\nbody"` directly to `core.heading_title`, bypassing `_read_text` entirely — so
  the contract the docstring claims is both violated in the real read path and untested by
  construction; no test would fail if `_read_text` stripped the `\r` outright.
- **F4 — Dot-prefixed files leak into `shell._markdown_files`.** `borg_core/link/shell.py:185-194`
  globs `directory.glob("*.md")`, which matches dot-prefixed filenames (e.g. `.foo.md`) because
  `pathlib.Path.glob` has no dotfile-hiding behavior. The zsh original's `*.md(N)` glob qualifier does
  not match dot-prefixed files by default (zsh's `dotglob`/`GLOB_DOTS` is off unless explicitly set,
  and `(N)` only suppresses the no-match error, it does not add `GLOB_DOTS`). This is an unreviewed
  behavior change from the port, not a decision — nobody has said whether a dot-prefixed directive or
  assimilated-plan file should be picked up or ignored.
- **F5 — No unit test exists for `_summary_block` itself.** `borg_core/link/render.py:98-112`
  composes `_fold_s` with a re-indent loop; `borg_core/link/test_render.py` tests `_fold_s` alone
  (`TestFoldS`, including the real-`fold`-binary parity check) but has no test that calls
  `_summary_block` and asserts on its output shape. The composition — not just the folding primitive —
  is what the deep-dive renderer's `^  [^ ]` contract actually depends on, and it is currently
  unverified.

## Objective

Close all five. They are independent of each other and may ship in any order or in separate PRs; none
blocks another.

## Acceptance Criteria

- [x] **AC1 (F1)** — `summarize_llm` normalizes internal newlines the same way the heuristic path
      does before returning, or `_summary_block` is made newline-safe regardless of what its input
      contains (pick one; document the choice in the fix's commit message).
  - Verify: a unit test feeding a summary string containing `\n` through the chosen fix point asserts
    the rendered `_summary_block` output has no line failing `^  [^ ]` other than the first.
  - **DECISION — fix `_summary_block`, NOT `summarize_llm`.** `^  [^ ]` is `_summary_block`'s OWN
    invariant, and this repo already ratified where an invariant lives: see the `borg recon`
    retirement gate (`docs/plans/assimilated/2026-08-26-recon-retirement-gate-altitude.md`) — the
    artifact that implements the command owns the invariant, not its caller. Normalizing only in the
    writer fixes today's single known writer and leaves the contract undefended against the next
    one. It also would not be sufficient: `lib/registry.zsh`'s `_borg_registry_write` scrubs control
    chars `\000-\010,\013,\014,\016-\037`, a set that EXCLUDES 0x0A, so a newline reaches storage
    intact and a hand-edited registry can produce one with no LLM involved at all.
  - **Evidence it holds:** `borg_core/link/render.py::_summary_block` now folds
    `"  " + summary.replace("\n", " ")`. `TestSummaryBlock::test_summary_block_flattens_an_embedded_newline`
    feeds `"first half\nsecond half"` and asserts every line after the header matches `^  [^ ]`;
    `..._flattens_newlines_before_folding_not_after` asserts a `\n` and a `" "` yield byte-identical
    blocks, so the fold budget is unchanged and no golden moved (`bats tests/` exit 0). MUTATION
    VERIFIED: reverting the fold argument to `"  " + summary` produced `2 failed, 3 passed` on
    `pytest borg_core/link/test_render.py -q -k summary_block`.
  - **SCOPE CORRECTION — the board is a SECOND renderer and it needed the same defense.** The first
    pass fixed `_summary_block`, which is the DEEP DIVE's renderer. `_overview_summary_cut` — the
    board's — did `summary[:50]` with no newline handling, so a `\n` inside the first 50 characters
    split one board row into two and sheared the fixed-width table exactly the way an over-long
    project name would. Same defect, same writer, second renderer. `_overview_summary_cut` now
    flattens BEFORE cutting, so the 50-char budget and the strictly-greater-than-50 ellipsis test
    both measure displayed characters. **Evidence:** `TestOverviewSummaryCut` — four cases covering
    the flatten, the boundary/ellipsis property, the no-golden-moves equivalence against the same
    string written with a space, and an end-to-end `_overview_row` assertion that one entry yields
    one line. MUTATION VERIFIED: reverting to `flat = summary` produced `4 failed` on
    `pytest borg_core/link/test_render.py -q -k OverviewSummaryCut`; `bats tests/` exit 0 confirms
    no golden moved.
- [x] **AC2 (F2)** — Correct the claim in `borg_core/link/cli.py`'s `main()` docstring to state the
      traceback leaked on **stderr** (not stdout), and that stdout/exit-code behavior was unchanged by the fix; the
      *why* (broad `except Exception` needed to cover AttributeError-shaped entry violations) stays as
      written.
  - Verify: `grep -n "on stdout" /Users/noah/dev/borg-collective/borg_core/link/cli.py` returns no
    hits inside the `main()` docstring.

  **Done 2026-08-28.** The clause now reads "an UNCAUGHT TRACEBACK -- stderr, exit 1, and no
  document", with a paragraph recording that the old wording named the wrong stream and could only
  ever have been wrong (Python writes an uncaught traceback to stderr, always, so no live run could
  have produced what it claimed). The *why* is untouched, restated only to make explicit that it does
  not rest on the false clause: what a `--json` consumer gets from an uncaught AttributeError is an
  empty out stream and a non-zero exit carrying no machine-readable reason.

  > **THE VERIFY CLAUSE IS NARROWED, NOT WAIVED, AND HERE IS THE EXACT READING.** The grep as
  > written still matches one line inside `main()`'s docstring: *"Both die formatters print to stderr
  > and exit 1 with zero bytes on stdout"*. That sentence is TRUE, is about the fixed behaviour rather
  > than the defect, and deleting it to satisfy a string match would trade a real invariant for a
  > green grep — the failure mode this repo files under "a check pointed at the wrong thing does not
  > fail, it reads as a pass". The clause is therefore read as its intent: **no surviving sentence in
  > that docstring claims a TRACEBACK reaches the out stream.**
  >
  > **Verified as a command and its outcome, not as line numbers.** `grep -n "on stdout"
  > borg_core/link/cli.py` returns hits inside exactly three docstrings — `_die_human`'s, `_run`'s and
  > `main()`'s — and each was read in full. None of the three says a traceback reaches the out stream:
  > `_die_human` promises `zero bytes on stdout` for the human die path, `_run` promises `zero bytes on
  > stdout, never a half-frame` for a mid-render exception, and `main()` carries the surviving sentence
  > quoted above. The correction paragraph is deliberately worded to add no fourth. **No line numbers
  > are recorded here on purpose:** any insertion above one invalidates it silently, and an earlier
  > revision of this very note pinned three that had all gone stale.
- [x] **AC3 (F3)** — Either fix `_read_text` to preserve `\r` (e.g. `newline=""` semantics) so the
      docstring's claim holds end-to-end, or correct `heading_title`'s docstring to say CR fidelity
      holds only for callers that bypass `_read_text`. Either way, add a test that routes a CRLF file
      through `_read_text` → `heading_title` (not an in-memory literal) and asserts the actual,
      current behavior.
  - Verify: `pytest borg_core/link/test_shell.py borg_core/link/test_core.py -q` includes a new test
    exercising `_read_text` on a real CRLF fixture file, and it passes.
  - **DECISION — correct the docstring; leave `_read_text` alone.** This directive's own Risks
    section says to confirm no live directive or assimilated-plan file is CRLF before flipping
    `_read_text`. Confirmed: `grep -rlI $'\r' --include='*.md' /Users/noah/dev/borg-collective`
    returns ZERO files. That cuts AGAINST flipping — the fidelity has no consumer, and preserving
    `\r` end to end would newly inject a trailing CR into rendered headings the day someone commits
    a CRLF file. That is a real rendering bug traded for a port-era parity claim whose port is
    finished.
  - **Evidence it holds:** `core.heading_title`'s docstring now states that the trailing `\r`
    survives only for callers that hand it text directly, and that `shell._read_text`'s
    `Path.read_text` applies universal-newline translation first, so the real read path yields a
    CR-free title. `test_shell.test_heading_title_of_a_real_crlf_file_on_disk_has_no_carriage_return`
    writes `b"# Title\r\nbody\r\n"` with `write_bytes`, byte-asserts the CRLF actually survived to
    disk (otherwise the fixture proves nothing), routes it through `_read_text` → `heading_title`,
    and asserts `"\r" not in text` and `== "Title"` — while re-asserting `"# Title\r\nbody"` still
    gives `"Title\r"` in memory. `pytest borg_core/link/test_shell.py borg_core/link/test_core.py -q`
    exits 0. MUTATION VERIFIED: adding `newline=""` to `_read_text` (the alternative fix direction)
    turned this test red, so it genuinely exercises the read path rather than passing vacuously.
- [x] **AC4 (F4)** — Decide and pin dot-prefixed-file behavior for `_markdown_files`: either filter
      them out (matching zsh's default) or explicitly document why they are now included.
  - Verify: a test creates a dot-prefixed `.md` file in a temp directives/assimilated directory and
    asserts the pinned behavior (present or absent) from `read_directives`/`read_assimilated`.
  - **DECISION — filter them out, matching zsh.** The port widened the glob silently:
    `pathlib.Path.glob` has no dotfile-hiding behavior, zsh's `*.md(N)` does (GLOB_DOTS is off
    unless set; `(N)` only suppresses the no-match error). Restoring zsh's answer is the
    port-parity contract, and dot-prefixed files are conventionally hidden scratch state — this
    repo carries an untracked `docs/research/.gate-armed` of exactly that shape, and a `.draft.md`
    surfacing in QUEUED would be wrong. No-op on current data:
    `find /Users/noah/dev -path '*/docs/plans/*' -name '.*.md'` returns nothing, so nothing can
    regress.
  - **Evidence it holds:** `shell._markdown_files` now filters `p.name.startswith(".")` before
    sorting. `test_shell.test_markdown_glob_excludes_dot_prefixed_files_like_the_zsh_glob` puts
    `.draft.md` beside `real.md` in directives and `.2026-03-02-b.md` beside `2026-03-01-a.md` in
    assimilated, and asserts the exact slug and title lists from `read_directives`/`read_assimilated`
    contain only the visible files. MUTATION VERIFIED: dropping the filter turned it red
    (`1 failed, 74 deselected`). The pre-existing
    `test_markdown_glob_includes_directories_like_the_zsh_glob` still passes, so the no-`is_file()`
    parity is untouched.
- [x] **AC5 (F5)** — Add a direct unit test for `_summary_block` covering at least: single-line
      summary, multi-line-after-folding summary (re-indent applied to lines 2..n only), and empty
      string.
  - Verify: `pytest borg_core/link/test_render.py -q -k summary_block` collects and passes at least
    one new test.
  - **Evidence it holds:** `borg_core/link/test_render.py::TestSummaryBlock` collects five tests
    under `-k summary_block` (`5 passed, 66 deselected`, exit 0): the single-line block asserted
    byte-exactly against `  {BOLD}Summary{NC}\n  a short summary\n`; a 40+1+40-char summary that
    folds at column 43, asserting line 1 keeps the indent the FOLD INPUT already carried (not
    double-indented) while line 2 is the one the re-indent loop produces; the empty string, pinning
    the bare `"  "` line as the one line on the page that legitimately fails `^  [^ ]`; and the two
    AC1 newline cases. MUTATION VERIFIED: changing the re-indent branch from `f"  {line}\n"` to
    `f"{line}\n"` turned `test_summary_block_reindents_lines_two_onward_only` red — the composition,
    not just `_fold_s`, is now covered.

## Scope Boundaries

- NOT re-running a fresh defect search on the link port — per the checkpoint that surfaced these,
  three rounds already found three real defects and a fourth found zero; these five are the tail of
  that same review, not a new pass.
- NOT touching `borg_core/recon` or any other subsystem.
- NOT re-litigating the deployed-artifact drift check
  (`docs/plans/directives/2026-08-14-deployed-artifact-drift-check.md`) — separate directive, already
  filed.
- If AC1-AC5 surface an actual production bug beyond what is described here (not just missing test
  coverage), fix it as part of the relevant AC rather than filing yet another directive for a variant
  of the same finding.

## Ship Definition

One PR (or five small PRs, contributor's choice) against `main`, each closing one AC with its stated
verify command green. `bats tests/*.bats` and `pytest -q` both still pass in full afterward.

## Timeline

Small. All five are additive tests plus a docstring correction (F2) and two narrow behavior decisions
(F1, F4) against already-decomposed pure functions. No architectural change expected.

## Risks

- **F1 and F4 both require picking a behavior, not just adding a test.** Resist the urge to make the
  "test-passes" choice without checking it against the documented zsh-parity contract
  (`PROJECT_PLAN.md` / the archived port plan) — a test that merely locks in whatever the code
  currently does proves nothing if the current behavior is the bug.
- **F3's fix direction (change `_read_text` vs. correct the docstring) has a real behavioral
  consequence either way**: preserving `\r` end-to-end changes what `heading_title` returns for any
  CRLF-authored markdown file already in a real project's `docs/plans/`. Confirm no live directive or
  assimilated-plan file is currently CRLF before flipping `_read_text`'s newline handling, or scope the
  fix to the docstring correction only.
