# Directive: Refuse the manifest — stop salvaging rows on read

*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Filed: 2026-09-01*
*Reverses: `docs/plans/assimilated/2026-08-27-degrade-the-row-not-the-manifest.md`*

**tl;dr** — Read-side row salvage was correct when invalid rows were expected. Validate-on-write plus
expand→migrate→contract makes them anomalies, and quietly salvaging an anomaly is a machine papering over a defect
instead of reporting it. Refuse the file, say so where the reader is looking, and make it structurally impossible for
a sync to delete a row the author declared.

## Why the earlier decision was right, and why it stops being right

`2026-08-27-degrade-the-row-not-the-manifest` shipped because one bad row cost a whole file. Measured then: a single
missing `gate.resolved_by` in row 3 deleted rows 1..14 from the grid, 12 declared refs became 5, and `▸ CHAINS`
rendered its "nothing declared here" placeholder as though the repository simply had none. A reader could not tell
*nothing declared* from *everything hidden by one typo*. Salvage was the right call **because invalid rows were a
normal, expected condition** — manifests were hand-authored, nothing validated them, and refusing the file meant
routinely losing a page over a routine mistake.

Two things landed on 2026-09-01 that remove that premise:

1. **`borg_core.manifest.shell.write_manifest`** validates and refuses. Nothing that goes through a borg writer can
   put an invalid row on disk.
2. **Expand → migrate → contract is now an Architecture Rule** (`CLAUDE.md`). The one case that could produce an
   invalid-on-read file without a bypass — a validator getting stricter under data written to looser rules — is
   unreachable when the migration precedes the tightening.

What remains are genuine anomalies: a hand-edit, a `git merge`, another tool. Salvaging those silently is the
failure mode this repo files under *"a check pointed at the wrong thing does not fail, it reads as a pass."*

**This is a reversal, not an extension, and it is filed rather than folded into the retirement because the decision it
reverses was assimilated.** It should be reviewable as its own argument.

## The change

1. **`_load_manifest` refuses the file whole.** `_drop_invalid_rows` and `core.partition_errors` lose their only
   caller on the read path. Decide on the record whether to delete them or keep `partition_errors` for the writer's
   error reporting — it is the only thing that maps an error back to a row index.
2. **`sync_borg` cannot reduce the row count on disk.** Today the only thing preventing that is an accident:
   `coordinator.py:398`'s `fatal = [w for w in warnings if ".json" in w]` happens to match every drop-warning because
   the message contains a path. Replace the substring test with a typed warning — a refusal is fatal for write,
   always. **Do this BEFORE repointing `discover`**, not after.
3. **A test asserts the invariant directly**, red by mutation: build a manifest with one invalid row, run the sync
   path, assert the row is still on disk.
4. **The reader's warning already surfaces and does not change.** `shell.py:143` emits its message and
   `link/render.py:1093` prints it in `▸ SIGNALS`.

## Already done, on 2026-09-01, ahead of this directive

The **fourth `▸ CHAINS` diagnosis shipped in `d7767ee`**, because it is a live bug today rather than a consequence of
this reversal: a whole-file refusal already happens (structural error, unreadable JSON, every row invalid) and already
renders "no project manifests in the registry yet." `_grid_placeholder` now tests `refused` first and says *"N
manifests could not be read."* This directive makes that arm fire more often; it did not create the need for it.

That ordering is deliberate and worth keeping: **the legibility fix landed before the behaviour change that depends on
it**, so the reversal cannot ship a state where files are refused and the page still claims none exist.

## Acceptance criteria

- [ ] **No read salvages rows.** A manifest with any invalid row loads as `(None, warning)`.
  - Verify: the partial-drop arm of `_drop_invalid_rows` has no caller; `test_a_partially_dropped_manifest_is_not_a_
    refusal` and the salvage cases in `borg_core/manifest/test_shell.py` are rewritten to assert refusal, and the
    rewrite is visible in the diff rather than deleted.
- [ ] **No write can reduce the row count on disk.** Including `borg chain sync` over a manifest with a bad row.
  - Verify: the test in step 3, red by mutation — restore the substring `fatal` filter and it must fail.
- [ ] **The page says which file and why.** A refused manifest names its path and its first error in `▸ SIGNALS`, and
      `▸ CHAINS` shows the fourth diagnosis rather than an emptiness sentence.
  - Verify: shipped in `d7767ee`; re-assert here against a real refused file end to end.
- [ ] **The reversal is recorded where the old decision is found.** A pointer in
      `docs/plans/assimilated/2026-08-27-degrade-the-row-not-the-manifest.md` naming this directive.
  - Verify: grep the assimilated file for this filename.

## Risks

- **A refusal is louder than a drop, and that is the point** — but it means one bad hand-edit removes a chain from the
  page entirely until fixed. Acceptable only because the fourth diagnosis makes the reason unmissable. If that arm
  regresses, this decision regresses with it; they are one change in two commits.
- **`make test-viz`'s fixtures assume salvage.** **57** shorthand ref occurrences (on 53 lines) in
  `merge-tree/test_coordinator.py` are invalid under `core.validate`. Per expand→migrate→contract they must be
  migrated **before** the read path tightens — the retirement's step 4, now load-bearing for two changes, not one.
  The rewrite must be **whole-file with a uniform owner**, not targeted at `_row(...)`: 41 of the 57 are join keys in
  recon state maps and target reports, and rewriting the row ref while leaving its state-map key turns the join into
  a silent no-match. A uniform prefix also preserves the lexicographic sort `coordinator.py:138` depends on, which
  per-repo owners would reorder.
- **The temptation when fixtures go red is to weaken the validator**, which is exactly how two validators came to
  disagree. Migrating the data is the only sanctioned fix.

## Notes

- Decided by Noah, 2026-09-01: *"if we always validate on write, then an invalid record upon read should be a hard
  exception so I guess b. But the big thing here is that we should never encounter the situation where some rows are
  invalid."*
- **Hard exception was qualified in the same conversation and the qualification is binding**: refuse the FILE, do not
  raise out of the reader. `borg_core/manifest/shell.py`'s header rule — one bad file must never blank the grid —
  still holds across the other 20 registered repositories. A refusal is a named warning plus an empty section for that
  manifest, never a traceback that costs the whole page.
- This is the D3 answer the merge-tree retirement was blocked on, and **this file is the resolver** — the decision is
  made, recorded here, and needs no further input. Step 3 of
  `docs/plans/directives/2026-08-31-retire-merge-tree-programs-into-borg-core.md`
  ("decide `sync_borg`'s row semantics deliberately") is answered by the "The change" section above. That
  retirement's next step is therefore its own step 4, the fixture migration, then the repoint — nothing is waiting on
  a person.
