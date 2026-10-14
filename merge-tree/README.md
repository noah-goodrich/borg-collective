# merge-tree — stack coordinator

The merge-tree browser board (the `data.json` / `story.json` pipeline and the `index.html` / `graph.html` / FastAPI "hub story lens" views) was **retired 2026-10-12**: `borg link` is the only place chains are drawn. See `docs/plans/assimilated/2026-10-03-retire-the-merge-tree-browser-board.md` for the inventory and the decision record. `curate.py`, `render.py`, `render_graph.py`, `spine.py`, `gather.py` and `app/` are gone; the machine-local state under `~/.local/state/borg/merge-tree` (`BORG_MERGE_TREE_DIR`) is no longer read by anything and may be deleted by hand.

What remains here:

- `coordinator.py` — the stack writer behind `borg stack list`, `plan` and `sync` (`borg.zsh` dispatches into it; `borg_core/reconcile/` cites it as the live reconcile writer).
- Manifests are read and written through `borg_core/manifest` (`shell.discover`, `shell.write_manifest`); the second copy that used to live here, `programs.py`, was retired into it (`docs/plans/directives/2026-08-31-retire-merge-tree-programs-into-borg-core.md`).
- `test_coordinator.py`, `test_s4_manifests.py` — its tests, gated by `make test-viz` and the CI `viz` job.
- `SCHEMA.md` — the live part is the stack-manifest contract (`<project>/.borg/chains/*.json`); the `data.json` and `story.json` sections are historical.
- `PROTOCOL.md` — the action-dispatch contract, historical alongside the board it served.
