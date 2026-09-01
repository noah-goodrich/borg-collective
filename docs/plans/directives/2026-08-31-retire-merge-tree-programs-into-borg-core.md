# Directive: Retire `merge-tree/programs.py` into `borg_core/manifest/`
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Filed: 2026-08-31*

**tl;dr** — AC7 decision 3, and the half of AC7 that is not a rename. Two diverged manifest implementations must
become one. This is filed rather than executed because a survey found roughly thirty traps in it, four of which
delete or silently discard user data while every existing test stays green.

## Why

`borg_core/manifest/core.py`'s module docstring assigns this directly: *"Retiring one of the two copies is AC7's
problem, not this module's."* The two copies are `merge-tree/programs.py` (the original, still live — `borg chain`
dispatches into `coordinator.py`, which rewrites manifests through its writer) and `borg_core/manifest/` (the port).

They have diverged **in both directions**, which is why "port to the stricter one" is not a safe default:

| | `merge-tree/programs.py` | `borg_core/manifest/` |
| --- | --- | --- |
| refs | accepts shorthand `r#1` | requires full `owner/repo#num` |
| `after` | no knowledge of the field; mis-derives silently | validates it and derives fork edges |
| `gate.kind` | closed to `{decision, verification}` | closure deliberately removed |
| bad rows | skips the whole file | drops the offending rows, keeps the file |
| `program` key | backfills from the filename | deliberately refuses to synthesise it |

Measured on `auth-hardening.json`: programs.py derives **6** edges (a linear chain), core.py derives **8** (the
declared fork). One file, two topologies, neither module raising.

## The four traps that are silent

Any of these ships green. They are the reason this is a directive.

1. **Row deletion.** `shell.discover` returns manifests with invalid rows removed in memory;
   `coordinator.sync_borg` writes back whatever `discover` returned. Repointing `discover` without first changing
   `sync_borg` makes `borg chain sync` **permanently delete rows from `<repo>/.borg/programs/*.json`** — exit 0,
   printing "wrote N manifest(s)". Every `test_coordinator.py` case stays green because they all build manifests
   that validate.
2. **Silent no-op.** `coordinator.py`'s `program = str(manifest.get("program") or "")` then
   `if not program: continue` has no warning branch. borg_core stamps `_id`, never `program`. After the swap, sync
   writes zero files, emits zero warnings, exits 0.
3. **`edges_from` does not exist in borg_core.** It looks ported because everything around it is. It was deleted
   there as dead, and `gather.py` still calls merge-tree's copy — an `AttributeError` at runtime, not import time,
   and `test_gather.py` never reaches `main()`.
4. **The coverage gate stops measuring.** `Makefile`'s `test-viz` names `merge-tree/programs.py` in a
   `coverage report --include=` list. `coverage` silently ignores an `--include` pattern matching nothing, so
   deleting the file shrinks the gate from six modules to five and prints a healthy TOTAL.

## Also true, and easy to trip over

- **`write_manifest` injects the retired word.** `to_write.setdefault("program", program)` stamps a top-level
  `"program"` key into every file on every sync — while `shell._load_manifest`, three files away, explicitly
  refuses to. Porting it verbatim means the commit that retires the word ships a writer that keeps writing it.
- **The `_id` leak.** `write_manifest` strips exactly `_path`. borg_core's loader stamps `_path` **and** `_id`. A
  verbatim port persists `"_id"` into every synced file. Nothing rejects it; the only symptom is a `git diff` on a
  tracked directory.
- **Fixtures go invalid either way.** Every ref in `test_coordinator.py` and `test_programs.py` is shorthand
  (`r#1`, `a#1`) — all invalid under `core.validate`. The natural "fix" when they go red is to weaken the ported
  validator, which is precisely the drift AC7 exists to end. `tests/fixtures/link/manifests/warehouse-rollout.json`
  is a live instance of the opposite: `kind: "review"` is writable under borg_core and rejected by merge-tree.
- **Ten of twenty symbols are dead weight.** `GATE_KINDS`, `PREREQ_ORDERS`, `programs_dir`, `_validate_apex`,
  `_validate_gate`, `_sort_key`, `_edge`, `_stacked_edges`, `_apex_edges`, `_blocks_edges` have zero references
  outside `programs.py` anywhere in the tree, and all ten already exist in borg_core in intentionally-diverged form.
  Porting them creates a second `GATE_KINDS` whose closure was deliberately removed on the other side.
- **`test_programs.py` opens `programs.py` by name.** `TestIndependence._sources` builds a literal path list to grep
  for forbidden external-plugin tokens. Deleting the module while keeping any part of that file raises
  `FileNotFoundError`, and that test is the mechanical guard against borg reading an external plugin's directory —
  it needs a new home, not deletion.
- **Four cases only look like duplicates.** The spine workstream wire (the only place `derive_edges`' `kind` token
  is checked against spine's `CHAIN_KINDS`), the on-disk fixture validation (borg_core rebuilds its fixture in
  Python by design), and two independence checks with different file coverage.
- **borg_core's own AC7 word-check and independence check are hardcoded tuples** (`for module in (core, shell)`).
  A writer landing in a new `borg_core/manifest/writer.py` is exempt from both — a `programs_dir()` name would ship
  green through the very gate AC7 installed.
- **`coordinator.py` calls the private `programs._rows`** twice. A mechanical swap to `core._rows` passes lint while
  binding merge-tree to a borg_core private the purity tests do not treat as a contract.
- **`evals/s4-k3/run.sh` is a real consumer and is already broken.** Two `import programs` heredocs, plus reads of
  `m["program"]` and `meta.program_contested_refs`. It hardcodes `/Users/noah` and is on-demand, not CI, so breaking
  it produces no red. Its silence is not evidence.
- **`make test-viz` had 11 pre-existing failures** before any of this (fixed on `fix/finish-the-employer-scrub`). A
  twelfth hides in that noise unless the baseline is green first.

## The change

1. **Port the writer first, additively.** `write_manifest` into `borg_core/manifest/shell.py` (not `core.py` —
   core is documented as unconditionally free of raw I/O). Decide two behaviours **on the record**: which validator
   it calls, and whether it still backfills `program`. Strip every `_`-prefixed key, not just `_path`. Move the
   `basename` discipline into the writer rather than leaving it in the caller. Consider `mkstemp` over a fixed
   `.tmp` name, which currently races and can orphan a temp file inside a git-tracked directory.
2. **Port `edges_from`**, which is simply missing.
3. **Decide `sync_borg`'s row semantics deliberately** — salvage-with-warning or skip-the-file — and write a test
   that fails if a sync ever removes a row the user declared.
4. **Migrate the fixtures to full refs** before repointing anything, so the validator swap cannot be "fixed" by
   weakening it.
5. **Repoint both importers**: `coordinator.py` (`discover`, `_rows`, `write_manifest`) and `gather.py`
   (`discover`, `edges_from`, `unmapped_gates`).
6. **Port the four non-duplicate tests** and rehome `TestIndependence`.
7. **Delete `programs.py` and `test_programs.py`; update the Makefile `--include` list in the same commit.**

## Acceptance criteria

- [ ] **One implementation.** `merge-tree/programs.py` no longer exists; nothing imports it.
  - Verify: `grep -rn "import programs"` returns nothing; `make test-viz` and `make test` green.
- [ ] **No sync can delete a declared row.** A test builds a manifest with one invalid row, runs the sync path, and
      asserts the row is still on disk afterward.
  - Verify: the test is red before the fix, by mutation.
- [ ] **The writer round-trips through the reader.** Anything the writer accepts, the reader loads — the asymmetry
      `core.py`'s docstring names is gone.
  - Verify: a property-style round-trip test over the fixture corpus.
- [ ] **Coverage still measures the moved code.** The `--include` list names the new location and the floor holds.
  - Verify: delete a ported function's tests locally and confirm the gate goes red.
- [ ] **The retired word is out of `merge-tree/`** and out of what the writer writes.
  - Verify: AC7's grep clause; plus a test that a written manifest gains no `_id` and no injected `program`.

## Notes

- Full survey behind this: five parallel readers over `programs.py`'s surface, borg_core's surface, the test-coverage
  delta, the blast radius, and the verb rename. Roughly thirty traps; the ones above are the load-bearing set.
- The verb rename half of AC7 shipped separately as `feat(ac7): rename borg program to borg chain`.
- **This is a Step 0.75 blocker that must SHIP, not be severed** — unlike the `project` → `repository` rename, which
  AC7 explicitly defers. AC7 cannot be ticked while two validators disagree.
- **It also blocks `borg reconcile`** in `2026-08-31-shim-architecture-for-borg-and-employer-plugins.md`: an
  automated writer on top of an unresolved reader/writer disagreement runs that risk on every timer tick instead of
  only when someone hand-edits.
