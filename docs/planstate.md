# Plan State: flipping acceptance criteria from evidence

`borg_core/planstate/` reads a plan's acceptance criteria, resolves each one's evidence against the real
world, and ticks the boxes it can prove. `/borg-link-up` calls it at session end, so plan state stops
depending on someone remembering to hand-edit markdown.

Parent directive:
[`2026-09-09-link-up-criteria-reconciliation.md`](plans/directives/2026-09-09-link-up-criteria-reconciliation.md).

## Why it exists

The 2026-08-20 completion audit measured the board lying in one direction: of 76 non-backlog open directives,
36 were verifiably shipped with unflipped checkboxes, and one fully shipped project sat at 0/44. Nothing in
the tree wrote those boxes — the only producer was a human editing markdown, which is the volunteered-capture
shape this project has already measured as failing.

`/borg-link-up` runs at exactly the moment the truth is known, already reads the plan, and already writes a
file. It was the natural writer and had never been given the job.

## The evidence annotation

A criterion opts in by carrying an indented `- Evidence:` sub-bullet beside its prose `- Verify:` line. The
prose clause is never touched or rewritten — the annotation sits *beside* it:

```
- [ ] **AC6 — e2e/eval harness MVP.** <prose>
  - Verify: <the human-readable clause, unchanged>
  - Evidence: `pytest:borg_core/planstate/`
```

Four kinds, and nothing else is accepted:

| Kind | Resolves by | `pass` when |
|------|-------------|-------------|
| `pr:<owner/repo#N>` | the same fetch path `borg link` uses | state is `merged` |
| `path:<repo-relative path>` | filesystem | the path exists |
| `bats:<path>` | the bats runner, chosen in code | exit 0 |
| `pytest:<path>` | `sys.executable -m pytest` | exit 0 |

**The annotation never carries a shell string.** It supplies a ref or a path matched against an anchored
`[A-Za-z0-9._/-]` class; the runner is selected in `shell.py` from the *kind*. A plan file is a document a
human edits and a nanoprobe writes — treating it as a source of commands would make every checkpoint an
arbitrary-code-execution surface. The gate is an allowlist, not a denylist of metacharacters, because a
denylist is a list of the attacks someone thought of.

An unannotated criterion is not an error. It resolves to `unknown` and is proposed, never flipped.

## The known limitation: a pin names a FILE, and a criterion is not always a file

Measured against this repository's own plan on 2026-09-16, when the first five annotations landed
(`noah-goodrich/borg-collective#211`). Two shapes of `Verify:` clause have no faithful annotation, and
both were found by trying rather than by reasoning:

**1. A pin is only as specific as the file it names.** AC1's pin is `bats:tests/cli_contract.bats` —
**165 cases**, of which roughly **10** touch what AC1 claims. Compare AC2's
`pytest:borg_core/link/test_picture.py`: 39 cases, all about the picture. So AC1's pin fails in both
directions: it goes red for unrelated CLI regressions, and — the serious one — **it can stay green
while AC1 specifically regresses**, because deleting the ten scope cases leaves the other 155 exiting
0. That matters more than it would for a reporting-only pin, because **`pass` auto-flips the
checkbox**: a 165-case suite is authorised to tick a specific criterion on evidence that is mostly
about something else.

**2. An annotation is ONE pin; a `Verify:` clause is often a conjunction.** AC7's reads: a scoped
`grep`, a file's existence, a coverage floor, *and* a suite. Pinning any single clause would flip the
criterion on a quarter of its evidence — and `bats:tests/cli_contract.bats` is green today, so it
would tick AC7 outright, which is deliberately unticked. AC6 is the same shape in a different key: its
gates are prose measurements of command output (`make eval` at `1 pass, 0 fail, 2 skip`), and no kind
expresses "this command exits 0 with these counts". Both are therefore left `unknown` **on purpose**,
which is why an unannotated criterion must stay a first-class outcome rather than a nag.

**Why the obvious fix is not obviously right.** The tempting repair is to move the ten AC1 cases into a
dedicated `tests/ac1_scope.bats` and pin that. Examined 2026-09-16 and NOT done: neither AC1 case is
self-contained. `tests/link_sweep.bats`'s case needs `_sweepable_repo` plus a sandbox that redirects
`XDG_DATA_HOME` to a *sibling* of `$HOME`, and its own comment records that a cache written there
"left all four assertions below green" until that root was listed. Re-authoring that harness in a new
file risks recreating the exact blind spot the comment exists to prevent. **Moving tests to fit the
annotation vocabulary is the tail wagging the dog.**

**The fix belongs in the vocabulary**, and the two clauses above suggest its shape: a pin that can name
a *case* rather than only a file, and a criterion that can carry more than one pin with `pass` meaning
*all of them passed*. Both are additive — existing single-file annotations keep their current meaning —
so this is an expand, not a migration. Filed here rather than as a directive because it belongs to
whoever next opens `borg_core/planstate/core.py`, and because filing a directive to fix a bookkeeping
gap would add a blocker to the very gate it improves.

## Three verdicts, and why `unknown` is not `fail`

- **`pass`** — flipped, with an audit annotation appended in the same atomic write.
- **`fail`** — the evidence was checked and the work is not done.
- **`unknown`** — nobody could check. A missing `bats:`/`pytest:` path means *the pin rotted*, not that the
  work regressed. An unreachable or unauthenticated `gh` means *we could not look*, not that the PR is open.

That distinction is load-bearing. `unknown` never flips and never reports a regression, which is what lets an
offline machine run `--apply` safely. It is also where every contract break lands, so treat a sudden rise in
`unknown` as a signal that something upstream changed shape.

A `path:` annotation is the one kind where absence is `fail` rather than `unknown` — it asserts *the file is
the deliverable*, so its absence is the work not being done.

## Using it

```bash
# What would change, and why. Writes nothing.
python3 -m borg_core.planstate.cli PROJECT_PLAN.md --json

# Same derive, then flip what it proved.
python3 -m borg_core.planstate.cli PROJECT_PLAN.md --apply
```

`--apply` implies the derive and reports it, so a caller never pays for two sweeps and cannot be handed a
proposal that disagrees with what was written. `--root` overrides the repo root that `path:`/`bats:`/`pytest:`
annotations resolve against; without it the root is the nearest ancestor containing `.git`.

There is **no `borg` subcommand** — the module is the entry point, called by the skill.
`BORG_PLANSTATE_SUITE_TIMEOUT` (seconds, default 300) bounds a suite run; a timeout is `unknown`.

## What the write guarantees

The only changes to the file are the checkbox character and, on that same line, an appended
`*(flipped by link-up: <evidence>)*`. Every other byte is unchanged — no reflow, no trailing-whitespace
normalisation, no touching of line endings. The write is atomic: a sibling tmp file, then `os.replace`, so a
crash leaves the plan byte-identical.

Two properties worth knowing:

- **Flips match criterion identity, not line position.** Indices are captured during a derive that may run for
  minutes (a `pytest:` annotation runs a suite) and a human may edit the plan in that window. The writer
  re-reads and requires the line to still *be* that criterion; a shifted file is a no-op rather than a wrong
  answer with the wrong evidence attached.
- **A re-run is a no-op.** An already-`[x]` criterion fails the prefix test, and a line already carrying the
  mark gets no second annotation.

The annotation has exactly one writer, and it is the engine. `/borg-link-up` must not append it — that was the
original design and it put a free-form markdown edit back into the write path, outside the atomicity the
engine promises.

## Module layout

| File | Role |
|------|------|
| `core.py` | **Pure.** Parsing, annotation validation, verdicts, the flip. No I/O of any kind. |
| `shell.py` | Every filesystem, subprocess and `gh` read. Reuses `link.shell`'s fetch rather than shelling out again. |
| `derive.py` | Orchestration: read, resolve, report, optionally write. |
| `cli.py` | `--json` / `--apply`, mirroring `borg_core/link/cli.py`'s shape. |

## Gotchas

- **A fenced code block is not criteria.** A plan that *shows* a `- [ ]` example — a template, a quoted diff —
  had every one counted as real work until 2026-09-11, found by running this engine against its own directive
  (10 criteria reported in a file with 9). `link/core.py::plan_progress` carries the same guard and the two are
  pinned to agree; a document where `borg link` says 3/10 and planstate says 3/9 has two truths in it.
- **Running `--apply` at the repo root forks a real pytest run** if any criterion carries
  `pytest:borg_core/planstate/`. That is this repo's own directive doing exactly what it says.
- **`pr:` state has one provenance path.** It rides `link.shell`'s batched `gh api graphql` fetch — one round
  trip for the whole document, and the same answer the board shows. A second resolver could disagree with
  `borg link` about whether a PR is merged.

## See also

- The directive, its 2026-09-10 amendment, and the 2026-09-11 restatement of AC2/AC8:
  [`2026-09-09-link-up-criteria-reconciliation.md`](plans/directives/2026-09-09-link-up-criteria-reconciliation.md)
- `docs/diagrams/plan-lifecycle.html` — where this sits in the directive lifecycle (ships on the
  docs branch; the link resolves once both land)
- `skills/borg-link-up/SKILL.md` — the caller
