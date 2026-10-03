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
- `merge-tree/fixtures/gather.raw.json` — the raw-gather fixture the curate, spine and gather tests share; delete only with
  whichever of them goes last

### NEEDS A DECISION (the one that is not obvious)

`merge-tree/gather.py` is the producer of `gather.raw.json` (#149), the recon-to-raw-gather bridge. Its downstream
consumers are `curate.py` and `spine.py`, both board-only — but `evals/s4-k3/run.sh` (E3) runs
`borg recon --json | python3 gather.py` to check declared-edge provenance, and `borg.zsh` and
`tests/cli_contract.bats` name it as a consumer of the `borg recon --json` machine surface. So it is board-fed code
with a non-board caller. Either E3 is re-pointed at `borg_core/manifest` and `gather.py` goes with the board, or
`gather.py` is kept as the eval's fixture builder. That choice belongs to this directive's first session, not to
this inventory.

## Acceptance Criteria

- [ ] **R1 — The decision above is made and written down**, and the "needs a decision" row is resolved into one of
  the two tables.
  - Verify: this file's inventory has no row under "NEEDS A DECISION".
- [ ] **R2 — Every reader of a retiring file is gone in the same change.** `grep -rn` for each retired module name
  across `Makefile`, `.github/workflows/`, `evals/`, `tests/`, `borg.zsh` and `docs/` returns only historical
  (severed/assimilated) prose.
  - Verify: the greps are run and their output recorded in the PR body.
- [ ] **R3 — The coverage gate is edited deliberately.** `VIZ_COVERED` names exactly the modules that survive, and
  `make test-viz` is green or the target is removed along with the CI `viz` job.
  - Verify: `make test-viz` and `make lint-viz`, or their documented removal.
- [ ] **R4 — The coordinator path is untouched.** `borg chain list`, `plan` and `sync` behave as before.
  - Verify: `bats tests/cli_contract.bats` and `merge-tree/test_coordinator.py` pass unchanged.
- [ ] **R5 — Machine-local board state is addressed.** The `~/.local/state/borg/merge-tree` files are listed in the
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

