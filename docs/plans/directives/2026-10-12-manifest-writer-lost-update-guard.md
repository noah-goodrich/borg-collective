# Directive: Close the lost-update race in `write_manifest`

*Filed: 2026-10-12 · Status: Proposed · Owner: Noah*

**tl;dr** — `borg_core/manifest/shell.py` `write_manifest` writes atomically (`mkstemp` + `os.replace`) but takes no lock, and `add-row` and `close` read the file, mutate it in memory, then write it back. Two concurrent runs can read the same bytes, and the second replace silently drops the row the first one added. The fix is a compare-and-swap on the file's content hash (or an advisory lock) so the second writer refuses or retries instead of overwriting.

## Why

- **The race is real and predates the refusal change.** `_cmd_add_row` and `_cmd_close` call `_read_for_write`, mutate the dict, then call `shell.write_manifest`. Nothing between the read and the write notices that the file changed underneath. `os.replace` is atomic for one write, not for a read-modify-write pair.
- **It limits the claim the refusal directive wants to make.** `2026-09-01-refuse-the-manifest-stop-salvaging-rows` makes "no write can reduce the row count on disk" structurally true for invalid files, and its Shipped note has to scope the claim because this race can still lose a row, silently, at exit 0.
- **It is rare today and gets likelier.** One orchestrator and a few nanoprobes can each run `borg chain add-row` against the same manifest in the same minute.

## The change

1. `_read_for_write` returns the sha256 of the raw bytes it read alongside the document.
2. `write_manifest` takes that digest as an optional `expected_digest`. Under an advisory `fcntl.flock` on a sibling lock file (so the check and the replace are one critical section), it re-reads the file, compares digests, and raises `ManifestChanged` on a mismatch, before anything is replaced. Callers that pass no digest (`scaffold`, which creates) behave as before.
3. `add-row` and `close` retry the whole read-modify-write a bounded number of times (`MAX_ATTEMPTS = 3`, declared up front) and then exit non-zero naming the file, rather than overwrite.
4. Alternative, same acceptance criteria: a plain advisory lock held across the read AND the write, with no digest. Pick whichever keeps `write_manifest` pure enough for the clean-architecture lint.

## Acceptance criteria

- [ ] **Two interleaved `add-row` writers cannot drop a row.** Both rows are on disk afterwards, or the loser exits non-zero naming the file; never a silent loss at exit 0.
  - Verify: a test in `borg_core/manifest/test_cli.py` interleaves two `add-row` runs (the second read happens between the first read and the first write, forced with a monkeypatched hook) and asserts both refs are present. Red by mutation: remove the digest check and it must fail.
- [ ] **A stale write is refused, not applied.** `write_manifest` called with an `expected_digest` that no longer matches the file raises and leaves the bytes untouched.
  - Verify: a test in `borg_core/manifest/test_shell.py` that edits the file between read and write and asserts `ManifestChanged` and a byte-identical file.
- [ ] **No new failure for the single-writer case.** Existing `add-row`, `close` and `scaffold` behaviour is unchanged.
  - Verify: `make test` and `bats tests/cli_contract.bats` are green with no test edited except the new ones.
- [ ] **The refusal directive's note is updated.** Once this ships, its Shipped caveat about concurrent writers is replaced by a pointer to this directive's shipped note.
  - Verify: grep `2026-09-01-refuse-the-manifest-stop-salvaging-rows.md` for `lost-update` and confirm the sentence reads as resolved.
