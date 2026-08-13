# Directive: Close the Untested-Branch Gaps in `borg recon`'s Python Core

*Filed: 2026-08-13*

Independent finding from a measured branch-coverage audit (`coverage run --branch`, commit `358f0aa`). Not a
child of the in-flight `borg link` Python-port plan — a separate subsystem, `borg_core/recon`.

## Why this exists

`borg recon` has already shipped dead once. Per CLAUDE.md (Learned): after the zsh→Python migration it read
`BORG_REGISTRY` from the environment with no fallback and died with `no registry at ` on every real
invocation except `--adapters` for weeks, because `borg.zsh` assigns that variable without `export`. No test
caught it because every test that reached the Python core supplied `BORG_REGISTRY` itself — the inheritance
path production actually walks was the one line no test ever executed.

A `coverage run --branch -m pytest` pass on the current `borg_core/recon` package (346 tests, all green)
finds several gaps with the identical shape: statement coverage is high (81-96% per file, 98% total), but
specific branches — the ones a real adapter or a real `--projects` flag would actually take — have never
been exercised. Two of them are HIGH: entire capabilities that are advertised as working and have never once
run under test.

## Verified findings

All line/arc citations below were re-checked against the current files in this worktree; none had moved.

- **`borg_core/recon/cli.py:46-53`** (`_collect_contradictions` loop body; arc `48->50` never taken, lines
  50-53 never executed) — **HIGH**. In every existing test, `by_project` is empty for every project, so the
  loop's `if not items: continue` always fires and the function never reaches `read_checkpoint_blockers()` or
  `core.project_contradictions()`. Contradiction detection — checkpoint says "blocked", source says
  "resolved" — is a headline `borg recon` capability. It has never run end-to-end under test. If it raises on
  a real sweep with real findings, nothing goes red.
- **`borg_core/recon/cli.py:59->61`** (`_filter_by_project`; `keep_names` always falsy in tests, lines 61-62
  never executed) — **HIGH**. The docstring says this function exists to make `--projects` authoritative even
  when an adapter over-returns items for other projects. Only the early-return-everything path
  (`if not keep_names: return by_project`) has ever run. The actual filter — `keep = set(keep_names)` /
  `{k: v for k, v in by_project.items() if k in keep}` — is unverified. A user scoping recon to one project
  could silently get every project's items back.
- **`borg_core/recon/core.py:144` and `147-148`** (`validate_track` False path; `normalize_track`
  TypeError/KeyError handler) — **MEDIUM**. Adapters are third-party executables dropped on
  `BORG_RECON_ADAPTER_PATH` by design (`shell.discover_adapters`), so a well-formed-JSON-but-wrong-shape
  payload, or one that raises inside `normalize_track`, is the *expected* failure mode from a bad adapter —
  not a hypothetical. These two handlers are the only thing standing between one bad adapter and an aborted
  fan-out, and neither has ever executed under test.
- **`borg_core/recon/core.py:207` and `209`** — **MEDIUM**. Line 209 (`continue` when `ref not in
  blockers_text`) is the no-contradiction negative case: a source item marked resolved whose ref does *not*
  appear in the checkpoint's blockers text. Every existing test feeds a ref that DOES match. Nothing proves
  the matcher can say no — a substring-match bug (e.g. an accidental short/generic ref) would produce false
  contradictions on every real sweep and the suite would stay green throughout.
- **`borg_core/recon/core.py:288->290`** (`_render_item_line`) — **LOW, but the directive's teaching
  example**. Both line 288 (`if item.get("action_needed"):`) and line 290 (`suffix += ")"`) are individually
  covered, so **statement coverage reports this function 100% and hides the gap entirely** — only
  `--branch` surfaces that the `action_needed=False` arc (skipping line 289's `", action"` suffix) has never
  rendered. Every item rendered in tests has `action_needed` truthy.
- **`borg_core/recon/shell.py:84-85, 87-88, 134-135, 189-190`** — **LOW**. Four never-exercised defensive
  skips: a checkpoint-dir glob entry that isn't a file (line 84-85, e.g. a directory literally named
  `*.md`); `file_mtime()` returning `None` on a stat failure (87-88); an empty segment in the colon-separated
  adapter search path (134-135, e.g. a leading/trailing `:` or `a::b`); and a checkpoint dir that exists but
  holds no `.md` files (189-190). Of these, the empty-PATH-segment skip is likeliest to fire in the wild —
  `adapter_search_path()` assembles two directories with a hardcoded `:` join (`shell.py:55`), and
  `BORG_RECON_ADAPTER_PATH` overrides are ordinary shell string concatenation, where a trailing colon is
  routine.

Full measured picture for context (statement/branch %, current):
`recon/cli.py` 81%, `recon/core.py` 96%, `recon/shell.py` 91%. See the companion directive
(`2026-08-13-coverage-gate-measures-the-wrong-thing.md`) for why the repo's gate doesn't currently show these
numbers by default.

## Objective

Close both HIGH gaps first, with tests that drive the real code path (not tests that assert the fallback
still works). MEDIUM and LOW gaps follow if time allows in the same pass; they are not required to ship this
directive.

## Acceptance Criteria

- [ ] **AC1** — A test drives `_collect_contradictions` through a non-empty `by_project` with a matching
      checkpoint blocker, asserting the returned contradiction list is non-empty and shaped correctly.
  - Verify: `coverage run --branch -m pytest borg_core/recon/test_cli.py -q && coverage report -m
    borg_core/recon/cli.py` shows arc `48->50` no longer in `Missing` and lines 50-53 covered.
- [ ] **AC2** — A test drives `_filter_by_project` with a non-empty `keep_names` that excludes at least one
      project present in `by_project`, asserting the excluded project is absent from the result and the
      included one survives unchanged.
  - Verify: `coverage report -m borg_core/recon/cli.py` shows lines 61-62 covered.
- [ ] **AC3** — Regression: full suite stays green.
  - Verify: `coverage run --branch -m pytest -q` exits 0 with the same or higher pass count (346+).

## Scope Boundaries

- NOT required to close the MEDIUM/LOW findings in this pass — listed above so they're tracked, not lost, but
  AC1-AC3 are the ship gate.
- NOT touching `borg_core/link` or `borg_core/registry` — this directive is `recon`-only.
- NOT changing `_collect_contradictions`, `_filter_by_project`, or any other production logic unless a test
  written against the real path actually finds a bug — the objective is coverage of the existing contract,
  not a rewrite.
- If done early: pick up the MEDIUM findings next, in the order listed above, rather than expanding scope
  elsewhere.

## Ship Definition

PR against `main`. New/extended tests in `borg_core/recon/test_cli.py` (AC1, AC2) exercising the real
branches; `coverage run --branch -m pytest -q` green; `coverage report -m borg_core/recon/cli.py` pasted into
the PR description showing the `48->50` and `61-62` lines no longer in `Missing`.

## Timeline

Small — one focused session. Both HIGH fixes are additive tests against already-decomposed pure functions
(`_collect_contradictions`, `_filter_by_project`); no production code changes are expected.

## Risks

- **A test that merely re-asserts the current behavior isn't a real check** if the current behavior is
  itself wrong (e.g. `_filter_by_project`'s actual filter has a latent bug nobody has seen because it's never
  run). Write the test against the documented contract in the docstring, not against whatever the code
  happens to currently do — if they disagree, that disagreement is the finding, not a red test to route
  around.
- **Contradiction detection touches `shell.read_checkpoint_blockers()`, which does real filesystem I/O.** Its
  own I/O boundary is already covered by `test_shell.py`; AC1 only needs to prove `_collect_contradictions`
  wires the (already-tested) pieces together correctly, not re-test the filesystem read.
