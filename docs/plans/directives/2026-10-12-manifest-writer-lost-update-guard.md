# Directive: Close the lost-update race in `write_manifest`, and probe the three item-state failure classes

*Filed: 2026-10-12 · Status: Proposed · Owner: Noah*

**tl;dr** — Scope is three failure classes (done-signal gap, lost update or double resolution, decision propagation gap), a writer audit of every path that changes item state, and the probe rules in the 2026-10-13 amendment below. The core fix is the `write_manifest` race: `borg_core/manifest/shell.py` `write_manifest` writes atomically (`mkstemp` + `os.replace`) but takes no lock, and `add-row` and `close` read the file, mutate it in memory, then write it back. Two concurrent runs can read the same bytes, and the second replace silently drops the row the first one added. The fix is a compare-and-swap on the file's content hash (or an advisory lock) so the second writer refuses or retries instead of overwriting.

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
  - Verify: a test in `borg_core/manifest/test_cli.py` interleaves two `add-row` runs (the second read happens between the first read and the first write, forced with a monkeypatched hook) and asserts both refs are present. Red by mutation: the harness switch from test requirement 4 disables the digest check, and the test must fail in that arm.
- [ ] **A stale write is refused, not applied.** `write_manifest` called with an `expected_digest` that no longer matches the file raises and leaves the bytes untouched.
  - Verify: a test in `borg_core/manifest/test_shell.py` that edits the file between read and write and asserts `ManifestChanged` and a byte-identical file.
- [ ] **No new failure for the single-writer case.** Existing `add-row`, `close` and `scaffold` behaviour is unchanged.
  - Verify: `make test` and `bats tests/cli_contract.bats` are green with no test edited except the new ones.
- [ ] **The refusal directive's note is updated.** Once this ships, its Shipped caveat about concurrent writers is replaced by a pointer to this directive's shipped note.
  - Verify: grep `2026-09-01-refuse-the-manifest-stop-salvaging-rows.md` for `lost-update` and confirm the sentence reads as resolved.

## Amendment 2026-10-13: failure classes and the writer audit

*Provenance: widened by Noah's 2026-10-13 decision after a research review of an external agent-skill project. The three classes were seeded from public issues on that project's tracker; the tracker is a seed list only and nothing is imported from it.*

Scope change: the existing change above (the compare-and-swap in `write_manifest`) stays as written and is the fix for class 2 on the manifest path only. This amendment adds the other two classes as named failures, an audit of every code path that changes an item's state, and the test rules the probes must meet.

### Failure classes

Each class is defined by what goes wrong, not by which mechanism causes it. A probe for a class passes only if it cannot produce that outcome through any writer in the audit below.

1. **Done-signal gap.** Work finished in the world (a PR merged, a plan completed) is never recorded as done in the item's state, so the ready frontier keeps listing it and the next-item view goes stale.
2. **Lost update / double resolution.** An item's recorded state loses or duplicates a transition that was reported as done, regardless of how it happened. Concurrent sessions are one cause; others are a stale worktree copy written back, a checkout, merge or rebase that reverts a tracked manifest, and a check-then-act claim with no lock. This directive's existing core is the manifest-write instance of this class.
3. **Decision propagation gap.** A decision is locked, but items that depend on it (open rows, plans, criteria that still describe the old design) are not flagged or updated, so the next reader of those items sees a state that contradicts the decision.

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
| W11 borg next, resolve | - | n/a | n/a |
| W12 borg start | C2 | no | no |
| W13 assimilate archival | C1, C2 | no | no |
| W14 borg-plan-promote hook | C2 | no | partial |
| W15 agent checkbox ticks | C2 | no | n/a |
| W16 hand edits, git-level overwrites | C2 | n/a | n/a |
| W17 external .stacks writers | C2 | n/a | n/a |

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
- **W11 borg next, resolve**: `borg next --rows --json` is read-only, and `borg_core.manifest.cli resolve` is documented read-only. Corrected from the first draft, which also said no hook writes item state; that was wrong (see W14). Confirmed by search, not by a run.
- **W12 borg start**: `borg.zsh:cmd_start` (about line 2396). Checks `[[ -f $plan ]]`, then `git mv` or `mv` of the directive to `PROJECT_PLAN.md`. A check-then-act with no lock: two sessions can both pass the check and both claim, which is C2 by the claim wording. Probe type: a bats test of the zsh path with a forced gap between check and move.
- **W13 assimilate archival**: `skills/borg-assimilate/SKILL.md` archives `PROJECT_PLAN.md` to `docs/plans/assimilated/` and moves directives to `assimilated/` or `severed/` with `git mv`. These moves are the real done-signal for plans (C1 if skipped), and two sessions archiving the same plan is C2. Skill prose, so the probe is a documented non-probeable path with a detector (see Test requirements).
- **W14 borg-plan-promote hook**: `hooks/borg-plan-promote.sh` writes `docs/plans/PROJECT_PLAN.md` from an in-session plan. It re-checks that no plan exists (Gate 4) well before the write, with no lock, so a concurrent `borg start` and the hook can both create a plan.
- **W15 agent checkbox ticks**: agents tick acceptance checkboxes in directives and `PROJECT_PLAN.md` with the Edit tool, bypassing `planstate --apply` and its re-read guard. Out of scope for a code fix; the detector is the planstate drift check (a ticked box with no evidence).
- **W16 hand edits, git-level overwrites**: hand edits of manifest JSON, and `git merge`, `rebase` or `checkout` of tracked manifests across worktrees, can revert or overwrite a row. Explicitly out of scope for a guard (git owns it); in scope for a detector that compares row counts across a sync.
- **W17 external .stacks writers**: `.stacks/` manifests are read by borg (`merge-tree/coordinator.py`) but may be written by tools outside borg. Out of scope to guard; the `write_manifest` digest check protects borg's own write against their changes, which is the only part this directive owns.
- **Not in the table**: `borg_core/registry/shell.py:write_registry` writes the project registry, not item state, and is out of scope here.
- **No writer takes a lock.** `fcntl.flock` appears nowhere in these paths. Only W8 re-reads.

### Test requirements

These answer the round-3 reviewer's objections. They apply to every probe added under this directive.

1. **Every writer gets a named probe type.** Each row of the audit table is assigned exactly one of: (a) a CLI interleaving test in pytest (W1, W2, W3, W4, W9); (b) a bats test of the zsh or bash path (W12, W14); (c) a documented non-probeable path with a detector, meaning a check that runs later and reports the symptom (W5, W6, W7, W13, W15, W16, W17); or (d) out of scope with a stated reason (W8 beyond its existing re-read, W10, which is a rare by-hand migration). W6 is probed by its detector: a merged PR with an open row must be reported by the ready-frontier check. A happy-path `/borg-assimilate` run alone is not a probe for class 1. Adding a new item-state writer without a row and a probe type is a review blocker.
2. **"Class absent" is defined per class.** Class 1 is absent when, for every writer assigned (a) to (c), a finished item is either recorded done or reported by a detector within one run of the check. Class 2 is absent when no probe in (a) or (b) can produce a silent loss or a duplicate resolution at exit 0. Class 3 is absent when a locked decision causes its dependent items to be flagged; today no mechanism exists (see the class 3 note).
3. **Races need forced interleaving or stress.** Each class-2 probe in (a) or (b) either forces the interleaving deterministically (a hook between the read and the write) or runs a stress arm. Stress arm: N = 50 concurrent writers, a 60 second timeout ceiling, and 5 consecutive passing runs required, with every row asserted present. A single pass at N = 50 is not enough.
4. **The mutation switch lives in the probe harness.** Each class-2 probe exposes an env or monkeypatch switch that disables the guard under test (for example `BORG_TEST_DISABLE_MANIFEST_GUARD=1`, honored only by the test harness). The probe runs both arms with plain pytest or bats: guard on must pass, guard off must fail. The verifier re-runs both arms; it never edits source. The text must not say the verifier applies a mutation, because its tools are Bash, Read, Grep and Glob and it is told never to modify files.
5. **A failing probe has a bounded ending.** A probe that fails and whose fix exceeds a patch (more than about 50 changed lines in non-test code, or more than 2 files) lands as `xfail(strict=True)` with the reason and a link to a real filed issue number, so a later fix turns the suite red until the marker is removed. Non-strict `xfail` is not accepted, and neither is a prose note with no test. `xfail` is forbidden for the W1, W2 and W4 manifest path: that fix is the core of this directive and must land green. Scope does not grow inside this directive to make other probes green.
6. **Authorship and verification are separate agents.** The probes are written by a build agent, because the read-only verifier has no Edit or Write and cannot create a test file. The verifier runs both arms of each probe, confirms the guard-off arm is red, and confirms every writer found by the audit search maps to a row. The verifier does not author the probes and the author does not certify them.

### Class 3 note

Decision propagation is likely present today with no mechanism at all: nothing in the audit above reads a locked decision and reaches its dependent rows or plans. So a class-3 probe is expected to fail, and per requirement 5 it lands as an xfail(strict=True) test plus a filed follow-up issue (class 3 is not on the W1, W2, W4 path, so the ban does not apply). Building the propagation mechanism is a feature and a separate future slice, not part of this directive.

### Acceptance criteria added

- [ ] **The writer audit table is kept true.** Every function that writes item or manifest state appears in it with its class, lock and re-read answers.
  - Verify: search `borg.zsh`, `drone.zsh`, `lib/`, `hooks/`, `bin/`, `skills/`, `borg_core/` and `merge-tree/` for `write_manifest`, `os.replace`, `write_atomic`, `write_text`, `open(` with a write mode, `os.fdopen` with a write mode, `mv`, `git mv`, and shell redirects (`>`, `>>`, `tee`) aimed at manifest, plan or directive paths, excluding `test_*.py`, `tests/` and `evals/`. Every hit maps to a table row or to a written exclusion in the Not-in-the-table list. Skill prose that instructs a state edit counts as a hit.
- [ ] **Each class has a probe set meeting the test requirements above**, or an `xfail(strict=True)` test plus a filed follow-up issue (never for W1, W2, W4).
  - Verify: the probe files exist, each class-2 probe runs both arms (guard on green, guard off red) under plain pytest or bats, and a separate verifier run re-executes both arms.
