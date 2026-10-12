# Directive: Retire the merge-tree browser board
*Filed: 2026-10-03*

**tl;dr** — Noah ruled on 2026-10-03 that the merge-tree browser board is retired and `borg link` is the only place
chains are drawn. This was One Front Door's intent ("the single front door",
`2026-08-24-one-front-door-link-derived-fact-surface`), and the teardown it implied was never filed. This directive
is the INVENTORY that teardown needs: what serves the board, what something else still needs, and what must be
decided before anything is deleted. **Nothing is deleted by filing it.**

## Why

Two chain models exist and the second is the one that carries load. The edge source is one thing,
`.borg/chains/*.json`, feeding two derived views: `story.json` (persisted, produced by `gather.py` then
`spine.py`, read only by the browser board) and the `borg link` grid (computed on every invocation, from the
manifests plus the live sweep). Nothing under `borg_core/` reads `story.json` (`grep -rn story.json borg_core/` is
empty). Keeping the board alive means keeping a second edge derivation, a second renderer family, a coverage gate
(`make test-viz`, the CI `viz` job) and a hand-run refresh nobody has wired — all for a surface the ruling says is
not a front door. The ruling that settled this is recorded in
`2026-08-11-viz-3-cross-repo-chains` (Rulings) and in the severed viz-1 and viz-2.

## Inventory — measured 2026-10-03 against `main` at `c8db947`

### Serves ONLY the board (retire candidates)

- `merge-tree/render.py` — the LEGACY renderer; writes `index.html`. `grep -c REVIEW_BUCKET` returns 4
- `merge-tree/render_graph.py` — the Story-Lens renderer; reads `story.json` + `data.json`, writes `graph.html`
- `merge-tree/spine.py` — the `story.json` skeleton generator (viz-2, #144)
- `merge-tree/gather.py` — the recon-to-raw-gather bridge (#149) and `gather.raw.json`'s producer; added per R1 below, with `test_gather.py` and `fixtures/gather.raw.json`
- `merge-tree/curate.py` — gather to `data.json`, including the awaiting-you derivation (viz-1, #125); its readers are
  `render.py`, `render_graph.py` and the board app
- `merge-tree/app/` — the FastAPI "hub story lens" (`app.py`, `graph.py`, `static/`, `serve.sh`, `README.md`); loads
  `story.json` and `data.json`
- `story.json`, `story.overlay.json`, `data.json`, `graph.html`, `index.html`, `annotations.local.json` — machine-local
  state under `~/.local/state/borg/merge-tree` (`BORG_MERGE_TREE_DIR`); not in the repo
- `make spine` — runs only `python3 merge-tree/spine.py`
- `make test-viz`, `lint-viz`, `format-viz`, the CI `viz` job, `VIZ_COVERED` — the gate that measures the modules above;
  `VIZ_COVERED` lists the live modules and must be edited, not left to shrink silently (see the guard comment above it)
- tests — `merge-tree/test_curate.py`, `test_render_graph.py`, `test_spine.py`, `merge-tree/app/test_graph.py`
- fixtures — `merge-tree/fixtures/data.golden.json` (curate/render goldens)
- docs — `merge-tree/README.md`, `PROTOCOL.md` and `SCHEMA.md` insofar as they describe `story.json`

### Something ELSE still needs it (do NOT delete without a replacement)

- `merge-tree/coordinator.py` — `borg chain list`, `plan` and `sync` in `borg.zsh` dispatches into it;
  `borg_core/reconcile/` cites it as the live reconcile writer
- `merge-tree/programs.py` — imported by `coordinator.py`, `gather.py`, `test_coordinator.py`, `test_programs.py`,
  `test_s4_manifests.py`; `evals/s4-k3/run.sh` (E2) shells into it. Its retirement is already filed:
  `2026-08-31-retire-merge-tree-programs-into-borg-core`
- `merge-tree/test_coordinator.py`, `test_programs.py`, `test_s4_manifests.py`, `fixtures/programs/` — the tests for the
  two modules above
- (`merge-tree/fixtures/gather.raw.json` was listed here as shared by the curate, spine and gather tests; all three
  readers went in the same PR, so it went with them.)

### DECIDED (R1, Noah, 2026-10-12): `gather.py` retires with the board

`merge-tree/gather.py` was the producer of `gather.raw.json` (#149), the recon-to-raw-gather bridge. It was board-fed code with one non-board caller: `evals/s4-k3/run.sh` (E3) ran `borg recon --json | python3 gather.py` to check declared-edge provenance, and `borg.zsh` and `tests/cli_contract.bats` named it a consumer of the `borg recon --json` machine surface. Noah decided on 2026-10-12 that `gather.py` is retired with the board and E3 is re-pointed at `borg_core/manifest` (shell discovery, `core` edge derivation, `across.contested_refs`), keeping its assertions: the authored declared-edge count and zero contested refs.

The `gather.py` row is therefore in the retire table: `merge-tree/gather.py`, `merge-tree/test_gather.py` and `merge-tree/fixtures/gather.raw.json` (all of the fixture's readers go with it) are deleted in the same PR as the rest.

## Acceptance Criteria

- [x] **R1 — The decision above is made and written down**, and the "needs a decision" row is resolved into one of
  the two tables.
  - Verify: this file's inventory has no row under "NEEDS A DECISION".
- [x] **R2 — Every reader of a retiring file is gone in the same change.** `grep -rn` for each retired module name
  across `Makefile`, `.github/workflows/`, `evals/`, `tests/`, `borg.zsh` and `docs/` returns only historical
  (severed/assimilated) prose.
  - Verify: the greps are run and their output recorded in the PR body.
- [x] **R3 — The coverage gate is edited deliberately.** `VIZ_COVERED` names exactly the modules that survive, and
  `make test-viz` is green or the target is removed along with the CI `viz` job.
  - Verify: `make test-viz` and `make lint-viz`, or their documented removal.
- [x] **R4 — The coordinator path is untouched.** `borg chain list`, `plan` and `sync` behave as before.
  - Verify: `bats tests/cli_contract.bats` and `merge-tree/test_coordinator.py` pass unchanged.
- [x] **R5 — Machine-local board state is addressed.** The `~/.local/state/borg/merge-tree` files are listed in the
  PR for the operator to delete by hand; the repo never removes state outside itself.
  - Verify: the PR body lists them.

## Scope Boundaries

- NOT deleting anything in the filing of this directive. The board is retired by ruling; its code is removed by the
  PR this directive describes.
- NOT touching `coordinator.py` or `programs.py` beyond what `2026-08-31-retire-merge-tree-programs-into-borg-core`
  already scopes.
- NOT building a replacement browser view. If one is ever wanted it is a new decision, not a fallback.
- If done early: ship, don't expand.

## Ship Definition

PR against main, CI green including the macOS contract leg, with R2's greps recorded in the body.

## Risks

- **A deleted module disarms a gate while the number goes UP.** `coverage report --include=` silently ignores a
  pattern that matches nothing, which is why `VIZ_COVERED` carries an existence guard. Edit the list in the same
  commit as the deletion.
- **`gather.py` is the quiet dependency.** Retiring the board without resolving the decision above breaks
  `evals/s4-k3` E3 with no failing unit test, because the eval is not a CI job.
- **`borg.zsh`'s comments mention `merge-tree/` paths.** They are comments, but `borg_core/reconcile/` and
  `borg chain` depend on the real `coordinator.py` path; do not move that file as a side effect of tidying.

