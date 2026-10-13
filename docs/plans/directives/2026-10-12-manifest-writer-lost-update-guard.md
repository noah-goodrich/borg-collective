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

## Amendment 2026-10-13: failure classes and the writer audit

*Provenance: widened by Noah's 2026-10-13 decision recorded in `docs/research/2026-10-13-matt-pocock-skills/recommendation.md` (the round-3 blind-review objections are in that file). The three classes were seeded from public issues on another project's agent-skill tracker; that tracker is a seed list only and nothing is imported from it.*

Scope change: the existing change above (the compare-and-swap in `write_manifest`) stays as written and is the fix for class 2 on the manifest path only. This amendment adds the other two classes as named failures, an audit of every code path that changes an item's state, and the test rules the probes must meet.

### Failure classes

Each class is defined by what goes wrong, not by which mechanism causes it. A probe for a class passes only if it cannot produce that outcome through any writer in the audit below.

1. **Done-signal gap.** Work finished in the world (a PR merged, a plan completed) is never recorded as done in the item's state, so the ready frontier keeps listing it and the next-item view goes stale.
2. **Lost update / double resolution.** Two concurrent sessions claim, close or overwrite the same item or the same manifest, and one result is silently dropped or both sessions believe they resolved it. This directive's existing core is the manifest-write instance of this class.
3. **Decision propagation gap.** A decision is locked, but items that depend on it (open rows, plans, criteria that still describe the old design) are not flagged or updated.

### Writer audit

Read-only audit of the tree at `origin/main` (5ba28b7). "Re-read" means the writer re-reads the target after its slow work and before it writes. Cell codes: C1/C2/C3 are the classes above, "-" is none.

| Writer | Classes | Lock | Re-read |
|--------|---------|------|---------|
| W1 add-row | C2 | no | no |
| W2 close | C2 | no | no |
| W3 scaffold | C2 | no | n/a |
| W4 write_manifest | C2 | no | no |
| W5 assimilate close step | C1 | no | no |
| W6 manual merge | C1, C3 | n/a | n/a |
| W7 link-up add-row | C2 | no | no |
| W8 planstate --apply | C2 (narrow) | no | yes |
| W9 merge-tree rewrite | C2 | no | no |
| W10 state migrate | C2 | no | no |
| W11 hooks, borg next | - | n/a | n/a |

- **W1 add-row**: `borg_core/manifest/cli.py:_cmd_add_row`. Reads once via `_read_for_write`, mutates the dict, then calls `shell.write_manifest`. This is the classic read-modify-write lost update.
- **W2 close**: `borg_core/manifest/cli.py:_cmd_close`. Same shape as W1. It also refuses an undeclared ref, which is correct, but a concurrent close of one ref by two sessions is last-writer-wins and both exit 0.
- **W3 scaffold**: `borg_core/manifest/cli.py:_cmd_scaffold`. It checks only that the root directory is not a file, then calls `write_manifest` with a fresh empty document. There is no existence check on the manifest itself, so on a name that already exists it appears to replace the whole file. Not verified by a run; the probe must confirm or clear this, and a confirmed clobber is the worst C2 instance in the table.
- **W4 write_manifest**: `borg_core/manifest/shell.py:write_manifest`. The common sink for W1 to W3 and W9. Atomic per write (`mkstemp` plus `os.replace`), no lock, no digest. The directive's change lands here.
- **W5 assimilate close step**: `skills/borg-assimilate/SKILL.md` "Close the manifest row". It shells out to W2 after the merge and is explicitly best-effort: a failed close never rolls back a merge. It is skipped when `resolve` finds no manifest. C1 is the intended-and-accepted failure mode here, so the done-signal depends entirely on the skill being run at all.
- **W6 manual merge**: `gh pr merge`, the web UI, or any merge that never touches borg. It changes the world state of an item and calls no borg writer. The research recommendation records `/borg-assimilate` as used 2 times with most merges bypassing it, so this is the most likely home of C1. It also cannot propagate a decision (C3). A direct `close` without a merge is the mirror case: state changes with no evidence.
- **W7 link-up add-row**: `skills/borg-link-up/SKILL.md` calls W1; inherits W1.
- **W8 planstate --apply**: `borg_core/planstate/derive.py:apply` then `borg_core/planstate/shell.py:write_atomic`. Flips plan checkboxes, not manifest rows. It does re-read the file just before writing and re-tests each target line, so it is the only writer that guards its read-modify-write; the remaining window is between that re-read and the replace, with no lock.
- **W9 merge-tree rewrite**: `merge-tree/coordinator.py:_rewrite_in_place`. Reads a manifest during discovery and rewrites it later through W4. Its row-count guard compares against the disk, but only against the count, so a concurrent add-row plus a concurrent removal can pass it. It holds the stale-read window open for the whole sync.
- **W10 state migrate**: `borg_core/statemigrate/shell.py:apply` and `repository_shell.py:apply`. File moves and copies of state with their own `write_atomic`; no lock. Run rarely and by hand, so low likelihood, but it is a writer.
- **W11 hooks, borg next**: no hook under `hooks/` and no `borg next` or link code writes item state; `borg next --rows --json` is read-only, and `borg_core.manifest.cli resolve` is documented read-only. Confirmed by search for manifest writes, not by a run.
- **Not in the table**: `borg_core/registry/shell.py:write_registry` writes the project registry, not item state, and is out of scope here.
- **No writer takes a lock.** `fcntl.flock` appears nowhere in these paths. Only W8 re-reads.

### Test requirements

These answer the round-3 reviewer's objections. They apply to every probe added under this directive.

1. **Every writer, including the bypass paths.** A probe set is adequate only if it exercises each writer in the audit table that can exhibit the class, including W6 (manual merge with no borg call) and a direct `close` with no merge. A happy-path `/borg-assimilate` run alone is not a probe for class 1; it is the path least likely to fail. Adding a new item-state writer without adding it to the table and the probe set is a review blocker.
2. **Races need forced interleaving or stress.** One sequential pass proves nothing about a race. Each class-2 probe either forces the interleaving deterministically (a hook between the read and the write, as in the existing acceptance criterion) or runs N concurrent writers with N declared up front (suggest N = 50 with a fixed ceiling), and asserts every row survives. Each such probe carries a mutation check: remove the guard and the probe must fail.
3. **A failing probe has a bounded ending.** If a probe fails and the fix would grow scope beyond a patch, the probe lands as an expected-failure test (`xfail` with the reason and a link) and a follow-up issue is filed. Scope does not grow inside this directive to make it green. A prose note with no test is still not a valid ending.
4. **Authorship and verification are separate agents.** The probes are written by a build agent (a nanoprobe or the main loop), because the read-only verifier has no Edit or Write and cannot create a test file. The verifier's job is to check that each probe can fail: it applies or reviews the mutation, confirms the probe goes red, and confirms the audit table has no unprobed writer. The verifier does not author the probes and the author does not certify them.

### Class 3 note

Decision propagation is likely present today with no mechanism at all: nothing in the audit above reads a locked decision and reaches its dependent rows or plans. So a class-3 probe is expected to fail, and per requirement 3 it lands as an expected-failure test plus a filed follow-up. Building the propagation mechanism is a feature and a separate future slice, not part of this directive.

### Acceptance criteria added

- [ ] **The writer audit table is kept true.** Every function that writes item or manifest state appears in it with its class, lock and re-read answers.
  - Verify: a search for `write_manifest`, `os.replace` and `write_atomic` call sites under `borg_core/` and `merge-tree/` yields no writer missing from the table.
- [ ] **Each class has a probe set meeting the test requirements above**, or an expected-failure test plus a filed follow-up.
  - Verify: the probe files exist, the mutation check for each class-2 probe is recorded as red, and a separate verifier run confirms it.
