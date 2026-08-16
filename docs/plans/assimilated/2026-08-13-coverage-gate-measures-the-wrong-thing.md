# Directive: Fix the Coverage Gate — It's Measuring Statements, and Test Files Are Grading Themselves

*Filed: 2026-08-13*

Independent finding from a measured branch-coverage audit (`coverage run --branch`, commit `358f0aa`). Not a
child of the in-flight `borg link` Python-port plan — a config fix to `pyproject.toml` that affects every
package under `borg_core`.

## Why this exists

The repo's coverage gate (`make test` → `coverage run -m pytest` → `coverage report -m --fail-under=90`)
reads an inflated number, for two independent, verified reasons.

### 1. `omit` matches nothing — test files grade themselves

`pyproject.toml`'s `[tool.coverage.run]` sets `omit = ["**/tests/**"]`. This repo does not colocate tests
under a `tests/` directory — it uses `borg_core/<pkg>/test_*.py` (e.g. `borg_core/recon/test_cli.py`), so the
omit pattern matches zero files. Measured on the current tree:

| | Statements |
|---|---|
| Total measured (`TOTAL` row, `coverage report`) | 2331 |
| In `test_*.py` files | **1407 (60.4%)** |
| Production (`cli.py`/`core.py`/`shell.py`/`paths.py`) | 924 |

**1407 of 2331 measured statements — 60.4% of everything the gate counts — are test files grading
themselves.** The reported `TOTAL` is **98%**. Re-measured with test files excluded (`--omit="*/test_*.py"`,
no `pyproject.toml` edit, just to isolate the effect): production-only coverage is **96%** — real, but 2
points lower than what's currently reported, and the number is currently invisible because nothing computes
it.

### 2. No branch coverage — statement coverage hides real gaps

There is no `branch = true` anywhere in `[tool.coverage.run]`, so every number this repo has ever reported is
**statement** coverage. The companion directive (`2026-08-13-recon-untested-branches.md`) has the concrete
proof: `borg_core/recon/core.py:288->290` (`_render_item_line`'s `action_needed` suffix branch) shows both
of its lines as individually covered — 100% by statement count — while the actual branch where
`action_needed` is falsy has never executed. Branch mode is the only thing that surfaces this; five more
gaps of the identical shape are cataloged in that directive.

### The fix — verified, not just proposed

One line changed, plus one line added, in `pyproject.toml`:

```
omit = ["*/test_*.py"]
```

plus `branch = true`. No `Makefile` edit needed — the `test` target's `coverage report -m --fail-under=90`
already inherits whatever `[tool.coverage.run]` sets.

**Verified this does not turn CI red.** With branch measurement enabled and test files correctly excluded:

```
$ coverage report --omit="*/test_*.py" --fail-under=90
...
TOTAL          924     34    316     14    96%
EXIT:0
```

924 production statements, 96% branch coverage, **8 points of headroom** above the `--fail-under=90` gate.
The change is safe to make today with zero remediation work required first.

### Connection to the active plan

The `borg link` Python-port plan's **A7** criterion already distrusts the global `--fail-under=90` for the
same underlying reason — its text: *"per-module coverage `>= 90%` checked by hand on `coverage report -m`,
not inferred from the global `--fail-under=90` (which is a total over `borg_core` and currently masks
`recon/cli.py` at 82%)"* (`PROJECT_PLAN.md:109-111`). Re-measured today, `recon/cli.py` is at **81%**
branch coverage (moved 1 point since A7 was written — expected drift, not a contradiction). A7 works around
the masking manually, per-plan, by hand-reading `coverage report -m`. This directive is the mechanical,
permanent fix: correct the gate itself so every future plan gets the real number without a manual step.

## Objective

Make `pyproject.toml`'s coverage config measure what the gate is supposed to measure: production code, by
branch, not by statement count inflated with self-grading test files.

## Acceptance Criteria

- [x] **AC1** — `[tool.coverage.run]` in `pyproject.toml` sets `omit = ["*/test_*.py"]` (replacing the
      dead `**/tests/**` pattern) and adds `branch = true`.
  - Verify: `grep -n 'omit\|branch' pyproject.toml` shows both lines under `[tool.coverage.run]`.
  - **Evidence**: `pyproject.toml:83` sets `branch = true`; `:84-86` sets `omit = ["*/test_*.py"]`.
- [x] **AC2** — With the new config, `coverage run -m pytest -q && coverage report -m` excludes every
      `test_*.py` file from the `TOTAL` row and reports branch columns (`Branch`, `BrPart`).
  - Verify: run the two commands above; no `test_*.py` file appears in the report; the header row shows
    `Branch` and `BrPart` columns.
  - **Evidence**: re-run confirms the coverage report lists production files only — no `test_*.py` rows —
    with `Branch`/`BrPart` columns populated.
- [x] **AC3** — `make test` (or the direct equivalent — `coverage run -m pytest && coverage report -m
      --fail-under=90`) still exits 0 with the new config, with the real production-only, branch-measured
      number visible in the report.
  - Verify: `coverage report -m --fail-under=90; echo $?` prints `0`; `TOTAL` row shows `924` statements (or
    the current production statement count if it has drifted) and a `Branch` column populated.
  - **Evidence**: exits 0. `TOTAL` row is now `1160` statements / `384` branches / `97%`, with the `Branch`
    column populated — the criterion's literal `924` has been superseded by the production codebase's growth
    since filing, per the criterion's own "or the current production statement count if it has drifted"
    clause; the number is not silently swapped, it's stated explicitly here.
- [x] **AC4** — No other file changes. This is a one-file, two-line config fix.
  - Verify: `git diff --stat` (against `main`) touches only `pyproject.toml`.
  - **Evidence**: PR #145's diff touches `pyproject.toml` only.

## Scope Boundaries

- NOT raising `--fail-under` above 90, even though there's 8 points of headroom — that's a separate decision
  with its own tradeoffs, not implied by this fix.
- NOT editing the `Makefile` — the `test` target already inherits `pyproject.toml` config with no changes
  needed.
- NOT fixing any of the branch gaps this makes visible (`recon/cli.py` at 81%, `recon/shell.py` at 91%,
  etc.) — that's the companion directive's job (`2026-08-13-recon-untested-branches.md`) and any equivalent
  future work for `link`/`registry`.
- If done early: ship, don't expand into a broader coverage-tooling overhaul.

## Ship Definition

PR against `main` changing only `pyproject.toml`. `coverage report -m --fail-under=90` output (showing the
real production-only branch number) pasted into the PR description as proof AC3 holds.

## Timeline

Trivial — a two-line config change plus a verification run. Well under one session.

## Risks

- **None identified that block shipping.** The 8-point headroom was verified directly (not estimated) before
  writing this directive, specifically to rule out "the fix reveals we were already failing." It doesn't.
- **Future drift**: if a package is added that doesn't follow the `test_*.py` colocation convention, `omit`
  would silently stop excluding it. No action needed now — flag it only if `borg_core`'s test-file naming
  convention ever changes.

*Shipped: 2026-08-15 — PR #145 merged to main*
