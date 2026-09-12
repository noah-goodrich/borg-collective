# Directive: AC5 — lifecycle skills author project manifests by default

*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Filed: 2026-09-12 · Status: PROPOSAL — awaiting evaluation*

**tl;dr** — AC5's engine shipped in
[#191](https://github.com/noah-goodrich/borg-collective/pull/191) and **nothing invokes it**. This
proposes the remaining three quarters: wire `/borg-plan`, `/borg-link-up` and `/borg-assimilate` to
the three write verbs, add ONE read-only verb so manifest selection is implemented in the core
instead of three times in three markdown prompts, and land a 3-positive/3-negative eval harness
whose oracle is the manifest file on disk. Six model cases behind `make eval-live`; a
model-free floor oracle in CI.

## Why this exists

`borg link` renders `▸ CHAINS` from `<repository>/.borg/programs/*.json`. Two manifests exist in the
whole estate and **both are hand-authored** — the parent plan's own Risks section names the
consequence: *"If AC5 is weak, `borg link` renders nothing and reads as broken. The authoring path is
load-bearing, not the renderer."* A second risk in that section is sharper still: *"`gate.kind` is
hand-set. A mis-set gate routes a human decision to an agent silently — a wrong answer, not a
missing one. AC5's evals are the only thing that would catch systematic drift."*

The write path is not missing. It landed 2026-09-04 as `borg_core/manifest/cli.py` — three verbs,
298 lines, 24 tests, a module docstring that names itself `(AC5)`, and a deliberate strict
read-modify-write that refuses rather than salvages. Measured this session: **zero callers**. `grep
-rn manifest skills/` over the three lifecycle skills returns nothing at all.

So this is the same failure shape as `reference_test_supplies_derived_value`, one level up: the
capability is built, tested, green, and not reachable from any surface a human or an agent actually
touches. The engine cannot be the deliverable, because a writer nobody calls produces exactly as
many manifests as no writer at all.

## What is already ratified and must not be re-litigated

Both decisions were taken 2026-09-04 and are recorded in `.borg/checkpoints/2026-09-04-1253.md`:

1. **`/borg-link-up` owns row CREATION.** Not `/borg-plan`, not `/borg-assimilate`.
2. **`/borg-plan` scaffolds apex + `rows: []`.** A plan declares a program exists; it does not know
   which PRs will implement it.

`/borg-assimilate` therefore only ever *closes* a row it did not create, which is exactly why
`close` refuses an undeclared ref instead of implicitly adding one.

## The mechanism

### 1. One new read-only verb: `resolve`

**This is the only new logic in the directive, and it exists to prevent one specific defect.** Three
skills each need the answer to "which manifest does this session's row belong to?" Written into three
markdown prompts, that is three implementations of one rule, drifting independently — the same shape
as the reader/writer disagreement AC7 is retiring `merge-tree/programs.py` to end, and as the two
validators `2026-09-01-refuse-the-manifest-stop-salvaging-rows` was filed over.

```
python3 -m borg_core.manifest.cli resolve --repository <root> [--plan <path>]
```

Read-only. Writes nothing, forks nothing. Prints one manifest stem on stdout and exits 0, or prints
a named reason on stderr and exits 1. The proposed rule, in order:

1. `<root>/.borg/programs/` absent or empty → exit 1, `no manifest declared` (this is the
   **no-op-and-propose** path, not an error condition for the caller to work around).
2. Exactly one manifest present → that stem.
3. More than one → the stem matching the active plan's slug, derived from `PROJECT_PLAN.md`'s
   eventual archived name the same way `/borg-plan` derives it.
4. More than one and no slug match → exit 1, `ambiguous: <stems>`. Never a guess.

`scaffold` keeps its `--name`, because at scaffold time there is nothing to resolve.

### 2. `/borg-plan` — scaffold, idempotently

At the point the skill writes `PROJECT_PLAN.md` (the `02-output` step), also:

```
python3 -m borg_core.manifest.cli scaffold --repository <root> --name <plan-slug> \
    --desc "<the confirmed Objective, one line>"
```

`_cmd_scaffold` is already idempotent and never clobbers — an existing file is reported at exit 0.
No `--apex` is passed: a plan has no PR yet, and AC5's ratified split says rows arrive at link-up.

### 3. `/borg-link-up` — add the session's row

Between the criteria reconciliation step (the `planstate` call) and the disk write, mirroring the
invocation style that step already established:

1. `resolve` the manifest. **Exit 1 → no-op, and write one proposal line in the checkpoint.** Never
   scaffold here; creation belongs to `/borg-plan`.
2. Derive the ref from the **production path**: `gh pr view --json number` against the current
   branch, yielding `owner/repo#N`. Degraded `gh`, no PR for the branch, or a detached HEAD → no
   row, one proposal line. Identical discipline to planstate's `unknown` is not `fail`.
3. `add-row --ref <ref> --lane <lane> --why "<one line>"`. Already append-or-update, so a re-run in
   the same session for a ref already declared is the ordinary case, not the exceptional one.
4. Report what was written in the checkpoint, beside `## Criteria Reconciled`.

**The ref is never recalled from the session's own narrative.** A model that believes it opened
[#204](https://github.com/noah-goodrich/borg-collective/issues/204) and actually opened
[#205](https://github.com/noah-goodrich/borg-collective/issues/205) writes a row pointing at someone
else's work, and `core.validate` cannot catch it because both are well-formed refs.

### 4. `/borg-assimilate` — close the row

After the merge step, for the ref just merged:

```
python3 -m borg_core.manifest.cli close --ref <ref> --status merged
```

A refusal (`no row declares <ref>`) is **reported, not repaired.** Either link-up never ran or the
ref is wrong, and both are things the author needs told. The skill must not fall back to `add-row`.

### 5. The eval harness — `evals/lifecycle-manifests/`

Two files, following the fixture discipline of
`claude-plugins/evals/pr-description/run.sh` (the exemplar the parent plan's AC5 clause names) and
the mode-floor convention of `evals/s4-k3/run.sh`.

**`run.sh` — six model cases, three pairs.** Each positive is paired with the negative that proves
the conditional discriminates. The oracle for every case is **the manifest file on disk**, compared
byte-wise where the assertion is "nothing changed" — never a grep of the model's prose, which is
what makes this harness a stronger gate than the exemplar it copies.

| Case | Prompt | Fixture | Passes when |
|---|---|---|---|
| P1 | `/borg-plan` | `git init`, no `.borg/` | `.borg/programs/<slug>.json` exists, validates, `rows: []` |
| N1 | `/borg-plan` | manifest already present, 2 rows | the file is **byte-identical** afterwards |
| P2 | `/borg-link-up` | manifest + stub `gh` reporting a PR | one row for that ref, correct lane and order |
| N2 | `/borg-link-up` | NO manifest | no manifest created, exit 0, checkpoint names the proposal |
| P3 | `/borg-assimilate` | manifest declaring the ref | that row's `status` is `merged`, no other byte moved |
| N3 | `/borg-assimilate` | manifest NOT declaring the ref | file byte-identical, and no row was added |

N1/N2/N3 are deliberately *not* "the input is absent". Each is a real regression surface: a
clobbering scaffold destroys a declared program, a scaffolding link-up dissolves the ratified split,
and a close that falls back to `add-row` manufactures the row it was meant to verify.

**Fixture rules, each from a measured failure in this tree:**

- Every fixture is **synthesized** by `git init` under `$OUT`. No case may name or require a second
  repository — that is what left `make eval-live` reporting a green sweep of nothing until
  2026-09-03.
- `gh` is supplied by a **stub in an allowlist bin dir derived from the skill's own needs**, never by
  `PATH="/usr/bin:/bin"`. `ubuntu-latest` preinstalls `/usr/bin/gh`; hiding a binary by naming
  directories it *isn't* in is a premise that holds only on macOS.
- The allowlist must include `bash` itself, or the `#!/usr/bin/env bash` shebang searches the PATH
  under test for its own interpreter.
- `$OUT` is recreated, not ensured. A stale artifact from a previous run is a false PASS for a case
  that produced nothing this time.
- `--skip-model` and `--skip-network` are both **accepted**, because `make eval` globs
  `evals/*/run.sh` and passes `EVAL_ARGS` to every harness — an unknown flag exits 2 and turns the
  whole target red. Every case here is a model case, so `--skip-model` requests nothing, runs
  nothing, exits 0 and says so; `--skip-network` is accepted and inert.
- One **model-mode execution floor**: reaching the end with `--skip-model` absent and zero cases
  executed is rc 1. SKIPs never gate (a `claude` that is absent or unauthenticated is a different
  fact from a `claude` that is wrong), but "every case skipped" and "every case passed" must not
  print the same rc 0.

**`floor-tests.sh` — the oracle for the guards, model-free, CI-runnable.** The floor lands with its
pair or it lands unobserved: claude-plugins measured a floor that could be deleted with every gate
still green. Minimum cases, each in the firing direction *and* the direction proving it
discriminates: `--skip-model` runs nothing at rc 0; the model floor fires when `claude` is hidden;
the cases SKIP rather than FAIL in that same run; the floor HOLDS when a stub `claude` lets one case
execute; the checkout guard refuses a bad `REPO` by name and a canary planted at `$OUT` survives;
the fixture builder produces a manifest-carrying repo and a manifest-less one that provably has no
`.borg` at all.

## What this does NOT change

- **`borg` gains no verb.** `resolve` is a verb of `borg_core.manifest.cli`, which the skills invoke
  directly, as `/borg-link-up` already invokes `borg_core.planstate.cli`.
- **No change to the three write verbs.** They shipped, they are tested, and the strict
  read-modify-write is the design. This directive adds callers and one read-only sibling.
- **No change to `borg link` or its renderer.** It already reads whatever is on disk.
- **No retroactive manifest authoring.** Prospective only. The two hand-authored manifests stay as
  they are.
- **Not AC7.** `merge-tree/programs.py` is retired by the parented
  `2026-08-31-retire-merge-tree-programs-into-borg-core` directive, not here. This directive touches
  `borg_core.manifest` only, which is the side that survives.

## Acceptance Criteria

- [ ] AC5.1 — `borg_core/manifest/cli.py` gains a read-only `resolve` verb implementing the four
      ordered rules above. It writes nothing and forks nothing.
    - Verify: pytest over `resolve` covering all four arms — absent dir, single manifest, several
      with a slug match, several without — plus an assertion that no file under the fixture
      repository changed mtime.
    - Evidence: `pytest:borg_core/manifest/test_cli.py`
- [ ] AC5.2 — All three lifecycle skills invoke the CLI unconditionally, with no opt-in language and
      no conditional the user must satisfy.
    - Verify: each of `skills/borg-plan/SKILL.md`, `skills/borg-link-up/SKILL.md`,
      `skills/borg-assimilate/SKILL.md` contains a `borg_core.manifest.cli` invocation; and the
      P1/P2/P3 eval prompts are the **bare slash command** with no manifest hint, so a pass is proof
      the behaviour is default rather than requested.
- [ ] AC5.3 — `evals/lifecycle-manifests/run.sh` runs the three positive cases headless and grades
      the manifest file on disk.
    - Verify: `make eval-live` reaches rc 0 with P1/P2/P3 executed and counted, not skipped.
- [ ] AC5.4 — Each positive is paired with a negative that fails if the conditional is removed.
      Asserted by mutation, not by presence: delete the `os.path.exists` guard in `_cmd_scaffold`
      and N1 goes red; make `/borg-link-up` scaffold when `resolve` exits 1 and N2 goes red; make
      `/borg-assimilate` fall back to `add-row` and N3 goes red.
    - Verify: the three mutations, run and recorded in the PR body.
- [ ] AC5.5 — `evals/lifecycle-manifests/floor-tests.sh` is green, needs no model, and runs on the
      same CI leg as the rest of the suite. Each guard is exercised in both directions.
    - Verify: `bash evals/lifecycle-manifests/floor-tests.sh` at rc 0 in the `test` job.
- [ ] AC5.6 — `make eval` (offline, the default `EVAL_ARGS`) stays green and the new harness does not
      turn it red by rejecting a flag it is handed.
    - Verify: `make eval` at rc 0; `make eval-live` at rc 0 with zero skips on a machine holding no
      repository other than this one.
- [ ] AC5.7 — Nothing breaks. `make test` green at its coverage floor, `make lint` at 10.00/10,
      `bats tests/` green, `shellcheck` clean over `evals/*/*.sh`.

## Testability

*(Required by this machine's `borg-plan` `02-output` extension.)*

- **Testable core:** `resolve` lands in `borg_core/manifest/cli.py` beside the three verbs it joins,
  covered by `test_cli.py` (24 cases today). The selection rule is pure given a repository path and
  a plan path; the only I/O is a directory listing and one file read.
- **Shell/wrapper:** the three `SKILL.md` files are the wrapper. They carry an invocation, never a
  schema and never a copy of the selection rule — that is the entire reason `resolve` exists rather
  than four prompt paragraphs.
- **What the passing test looks like before any refactor:** `resolve`'s four arms are new code and
  ship with their tests in the same commit, per the Architecture Rules. Nothing existing is
  refactored: the three write verbs are untouched, and `_manifest_path`/`_read_for_write` are reused
  as-is.
- **Existing code with no coverage, flagged rather than silently refactored:** the three `SKILL.md`
  files have **zero** automated coverage today, in this repo or any other — that is what AC5.3–AC5.5
  are for, and it is why the eval harness is a deliverable of this directive rather than a follow-up.
  `evals/s4-k3/run.sh` has no `floor-tests.sh` pair; this directive does **not** retrofit one for it
  (see Scope Boundaries).

## Scope Boundaries

- **NOT** a `floor-tests.sh` for `evals/s4-k3/run.sh`. That harness's cases are offline and
  network, so CI already runs its only universal case; retrofitting an oracle there is a separate
  call. Named so its absence is a decision rather than an oversight.
- **NOT** AC7's `merge-tree` retirement, and **NOT** the `project` → `repository` rename.
- **NOT** `gate.kind` authoring. The parent plan names a mis-set gate as a silent wrong answer, and
  the evals here would catch systematic drift — but *setting* the field from a session's context is
  its own judgment problem and would drag the directive into the same "model volunteers a value"
  territory the mechanical-gate amendment exists to leave.
- **NOT** retroactive authoring, and **NOT** an `apex` at scaffold time.
- **NOT** more than six model cases. Each is a full lifecycle-skill run; the harness is already the
  most expensive thing in the tree.
- If done early: ship it. Do not expand to a fourth skill.

## Ship Definition

PR against `main`. `make test` green at its floor, `make lint` 10.00/10, `bats tests/` green,
`shellcheck` clean over `evals/*/*.sh`, `make eval` green with the floor armed, **one `make
eval-live` run at rc 0 with zero skips**, and the three AC5.4 mutations run and their red results
pasted into the PR body. Then AC5 is ticked in `PROJECT_PLAN.md`.

## Timeline

Two sessions. The prompt edits and `resolve` are one sitting; the harness is the other, and it is the
one that runs long — six `claude -p` invocations of full lifecycle skills, each capable of taking
minutes, plus three deliberate mutation runs on top.

## Risks

- **The eval is the expensive half and the easy half to skip.** Six model cases means a real
  `eval-live` run is a coffee break, and the parent plan's AC6 spent nine decisions on exactly the
  failure this invites: a harness nobody runs reporting green. The `floor-tests.sh` pair is the
  mitigation, because it is the part CI can actually execute.
- **`/borg-link-up` grows a third engine call.** It already forks `planstate` (which can fork real
  test suites) and now adds `resolve` plus `gh pr view` plus `add-row`. Session flush is becoming a
  pipeline with a latency budget nobody has measured. Measure it; if a flush crosses a few seconds
  of subprocess time, that is a finding worth its own line in the PR body.
- **A stubbed `gh` proves the wiring, not the derivation.** P2 grades that a resolved ref reaches
  `add-row`; it cannot grade that `gh pr view --json number` returns the right ref against real
  GitHub. That gap is deliberate — the alternative is a case requiring a live PR, which is the
  "names a repository" premise this harness is forbidden from having — but it should be stated in
  the harness header rather than discovered later.
- **`resolve` rule 3 depends on the plan slug, which is derived, not stored.** `/borg-plan` derives
  the slug from the Objective line and nothing writes it down. If the Objective is edited after
  scaffold, rule 3 stops matching and `resolve` falls to rule 4 (`ambiguous`) — which proposes rather
  than guesses, so it degrades safely, but a repository with several manifests would go quietly
  un-updated. Worth considering whether `scaffold` should stamp the slug into the manifest itself.

## Open questions for the evaluator

Flagged rather than decided, because each changes the shape of the work:

1. **Should `scaffold` stamp its own stem into the document** so `resolve` rule 3 matches on stored
   state rather than a re-derivation? It is one more key and it removes the last Risk above — but it
   is also a schema change, which means expand → migrate → contract over two existing hand-authored
   manifests.
2. **Does `/borg-link-up` add a row for a branch with no PR yet?** The proposal says no (no ref, no
   row, one proposal line). The alternative — a row keyed on the branch name, upgraded to a PR ref
   later — would declare work earlier, at the cost of `core.validate` no longer being able to check
   that a row points at something real.
3. **Is the lane derivable, or does the model choose it?** The proposal passes `--lane` from the
   session's own judgment, which is the one place in this directive where a model still volunteers a
   value into a validated document. `core.DEFAULT_LANE` is the conservative alternative.
