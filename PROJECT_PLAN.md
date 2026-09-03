# Project Plan: One Front Door — `borg link` as the Derived-Fact Surface
*Established: 2026-08-24*

## Objective

Make `borg link` the single front door that answers, from a clean read of derived fact: what projects are in flight,
what's next for each, and which parts are Noah's vs the agent's — rendered identically everywhere — and land the
e2e/eval harness that keeps it honest.

## Vocabulary (ratified 2026-08-24, applies immediately)

- **Repository** — a git repo. What a drone opens on by default. Currently miscalled "project" throughout the code.
- **Project** — a set of related requirements, PRs, and work spanning one or more repositories. Previously and
  incorrectly called a "program."
- **"Program" is retired.** It does not appear in new code, output, skills, help text, or documentation —
  with one ratified exception: the REMOVED tombstone in `borg help`, which names a retired verb precisely so a
  user who types it gets a pointer instead of `unknown command`. See AC7 decision (1). The verb itself becomes
  `borg chain`, not `borg project`; see AC7 decision (2). The repository-side internal rename
  (`project` → `repository`) is deferred to a parented directive; see AC7.

## Acceptance Criteria

- [x] **AC1 — One front door, context-scoped, always a clean read.** In a repository, `link` sweeps that repository
      (~2.7s measured); in the orchestrator, it sweeps all (~12.5s measured, 13 repos). No cache, ever — a clean read
      every time. `--local` is the only opt-down. `recon` retires as a human-facing verb; no new verbs are added.
  - Verify: bats asserts `borg help` is net one command shorter than at plan start, and that two consecutive
    `borg link` runs write no cache artifacts.
  - **MET.** Both verify clauses pass (`contract: borg help is net one command shorter than at plan start (AC1)`,
    `cache: two consecutive borg link runs write no cache artifact (AC1)`) — and, unlike before, the stated goal holds
    too. The box was deliberately held unticked while `borg link --brief` answered from somewhere else: it returned
    from `_borg_link_dispatch` before any Python ran, so it never swept — measured at **zero `gh` subprocesses against
    every other arm's two** (one `pullRequests` sweep plus AC3's one `issueOrPullRequest` fetch). That fold shipped on
    branch `feat/fold-brief-into-the-document`, per
    `docs/plans/directives/2026-08-27-fold-brief-into-the-document.md`. `--brief` is now a presentation mode of the
    same document: it builds it ONCE via `_borg_py borg_core.link.cli --json`, projects that JSON into the narrative
    prompt, and re-renders those same bytes through the new `--render-document` seam when the narrative is
    unavailable. One sweep, one clock read, two consumers — and no hand-rolled fallback table left to drift from the
    real page, because the fallback IS the real page.
  - Evidence is a subprocess count, never a reading of the code (`tests/link_sweep.bats`, the one suite that restores
    the real adapter and the real fetch seam `setup_temp_dirs` neutralizes everywhere else):
    `sweep: link --brief sweeps exactly as link does, counted rather than read` asserts exactly one
    `pullRequests(first:` and one `issueOrPullRequest(number:` on the `--brief` arm, side by side with an identical
    count on bare `link`; `sweep: link --local --brief spawns zero gh subprocesses, and --brief without it sweeps`
    proves the one opt-down is really forwarded; and four cases force each `fallback_reason` branch — timeout,
    not-logged-in, non-zero exit, empty output — and assert the document renders under each. `tests/briefing.bats`
    covers the rest: none of its pre-fold cases were deleted, three were rewritten with the reason recorded in the
    file header, one was kept with new provenance, and the remediation passes below added `--all` forwarding, the
    repository-scope prompt breadth, and both no-page rungs (build and fallback render) being loud on **stderr** and
    non-zero out. Deliberately not stated as a count — the count was wrong by three within a day of being written,
    twice, in two files.
    `docs/plans/directives/2026-08-10-briefing-fallback-and-summary-provenance.md` **Phase 5** is closed and its
    **Phase 3** subsumed. **Phase 5b** (`/borg-recon`, the second un-folded human digest) is a skill rather than a
    command, blocks neither verify clause nor the stated goal, and stays filed separately.
  - **The first fold reintroduced the defect once, inside itself, and the tick is only honest with the remediation
    included.** The narrative projection read the TOP-LEVEL `.directives`/`.assimilated`, which `--json` always fills
    with the registry-wide aggregate, while the fallback page rendered from THE SAME BYTES narrows both to `focus` in
    repository scope. Measured on the author's registry: the prompt said `QUEUED: 141 open directives` plus three
    collective-wide plan titles while the page printed underneath it said "nothing queued" and "nothing shipped yet".
    One invocation, two answers — AC1's own failure class. The projection now binds breadth ONCE
    (`$breadth = if scope.kind == "repository" then focus else document`), transcribing `render._scoped_rows` rather
    than inventing a second rule, and `tests/briefing.bats`'s "in repository scope the prompt's QUEUED/SHIPPED match
    the page's, not the registry's" asserts it on the captured `claude -p` argument with an orchestrator-scope control
    beside it. Two smaller holes closed with it: a failed `jq` projection used to ship an empty `DOCUMENT:` block to
    `claude -p` and print the invented narrative with no reason line (it now takes the fallback with its own
    `fallback_reason`, jq's stderr included), and the empty-registry short circuit keyed off `total_projects`, which
    `core.assemble` fills from the UNFILTERED map — so an all-archived registry stopped short-circuiting and paid
    for a narrative about a board with no rows. It keys off `.order` now, the list actually projected.
  - **`--brief` is still the one invocation that prints something other than the seven sections**, and AC2's "never a
    different page" is qualified in CLAUDE.md rather than left to read as covering it. The narrative path prints prose:
    no cube, no `▸` headers. What AC1 claims, and what is tested, is that the prose is a rendering of the SAME
    document at the SAME sweep, and that the fallback is the real page byte for byte.
- [x] **AC2 — The topological grid is the renderer, everywhere.** Vertical, rows as levels with time flowing down,
      columns as branches, box-drawing connectors, state glyphs, compact nodes with detail blocks below, ANSI to
      stdout by default with OSC-8 hyperlinks on refs. Repository and orchestrator contexts differ in breadth only —
      never layout, section order, or vocabulary.
  - Verify: golden-file snapshot test rendering both contexts from fixture manifests; one render entry point.
  - **MET** in [#165](https://github.com/noah-goodrich/borg-collective/pull/165). Both contexts pinned by
    `_assert_link_grid_golden` against `link-grid-repository.golden` / `link-grid-orchestrator.golden`; `document()`
    is the sole render entry point (`render.overview` and `render.deep` deleted). Known gap, carried into AC4:
    neither fixture manifest declares a row `status`, so the goldens cannot catch a provenance-glyph regression in
    either direction.
- [x] **AC3 — Declared members outside the sweep resolve truthfully.** Any ref declared in a manifest but outside the
      current sweep window is targeted-fetched, never rendered `unknown`.
  - Verify: e2e case runs `borg link` inside one repository against a fixture manifest spanning several; asserts zero
    nodes render `unknown`.
  - **MET** in [#164](https://github.com/noah-goodrich/borg-collective/pull/164):
    `sweep: AC3 — a manifest spanning two repositories renders zero unknown nodes`.
- [x] **AC4 — Rows drive "next" and "yours vs mine."** Sourced from `rows[].next` and `gate.kind`, never re-derived.
      READY = open AND every parent merged, announced as a set. Adds row-level `after: [refs]` so forks are
      expressible (lanes only express linear tracks).
  - Verify: pytest over the derivation against fixture manifests including a fork case and a negative case.
  - **MET.** Implementation shipped in [#169](https://github.com/noah-goodrich/borg-collective/pull/169); the box was
    held unticked because the `unsure` group was UNREACHABLE THROUGH THE FRONT DOOR — `manifest_core.GATE_KINDS` closed
    `gate.kind`, so a row whose kind did not route was refused at load and the router only ever saw an unrecognized kind
    from a unit test handing it a string. [#175](https://github.com/noah-goodrich/borg-collective/pull/175) demoted the
    validator: a gate must NAME some kind, an unrecognized one is the router's concern, and an EMPTY one is still a
    row-scoped error (`_route("")` must keep meaning "no gate", never "a gate that named nothing").
  - **Never re-derived, by construction rather than by discipline.** `render.py` imports only `link.{core,grid,picture}`
    — never `manifest.core` — so it cannot call `ready_set` or rebuild the gate list. `_next_tally` reads
    `manifests[].ready.refs`, `manifests[].gates` and each node's `next`, all stamped by `grid.grid_manifest`;
    `grid.ready_refs` is the single derivation and it feeds `manifest_core.ready_set` RESOLVED states only, so a
    hand-typed `status: "merged"` can never light `●`. Pinned by
    `test_grid.py::test_a_declared_merged_parent_does_not_make_its_child_ready` and
    `::test_the_grid_carries_ready_but_still_no_duplicate_gate_list`.
  - **THREE-STATE, and the three are distinguishable.**
    `test_grid.py::test_nothing_ready_on_a_resolved_render_is_not_the_same_as_nobody_looking` asserts that the
    `known-empty` and `unlooked` results carry an identical `refs == []` and different `state`;
    `test_render.py::test_nothing_ready_and_nobody_looking_are_different_sentences` asserts the two render as different
    sentences, and `::test_a_partly_unlooked_board_reports_both_halves` covers the mixed orchestrator case where a real
    answer and an unlooked manifest coexist.
  - **Fork case and negative case, the verify clause's own two words.** Fork:
    `manifest/test_core.py::test_an_intra_lane_fork_announces_both_children_ready_at_once` — rows 1,2,3 in ONE lane
    where row 3 declares `after: [row 1]`, and READY announces BOTH children at once
    (`::test_a_fork_announces_both_children_at_once` is the cross-lane twin,
    `::test_after_overrides_lane_adjacency_so_an_intra_lane_fork_is_a_fork` and
    `::test_an_intra_lane_fork_puts_both_children_on_one_level` are the edge and level halves). Negative:
    `::test_the_same_lane_without_after_is_still_a_chain` — the identical lane with no `after` stays a chain and
    announces ONE row, so the fork is caused by `after` and not by the lane shape; joined by
    `::test_an_after_that_supplies_no_usable_parent_leaves_the_row_on_its_lane` (four unusable shapes),
    `test_grid.py::test_a_draft_pull_request_is_never_ready`, and
    `test_render.py::test_next_true_orders_within_a_group_and_never_grants_membership`, which pins `rows[].next` as
    EMPHASIS — it orders within a group and a flagged row that is not READY stays out entirely.
  - **`unsure` reaches the page END TO END, not just `_route`.**
    `test_render.py::test_an_unrecognized_kind_reaches_unsure_through_the_real_loader` starts from the shipped bytes of
    `tests/fixtures/link/manifests/warehouse-rollout.json` (`acme/warehouse#78`, `kind: "review"`), copies them into a
    `.borg/programs/` layout and runs `manifest_shell.discover` → validate → `gates()` → `ready_refs` → `_route` →
    `_next_section`: no warning, the row SURVIVES loading, and the group names the kind. The bats golden pins the same
    row's rendered form — `unsure — the gate says "review", which does not route` over `acme/warehouse#78` in
    `link-grid-orchestrator.golden`. Both were confirmed by MUTATION: restoring `kind not in GATE_KINDS` in
    `_validate_gate` fails the pytest (`1 of 6 rows dropped`) and turns `contract: link renders the orchestrator context
    byte-identically to its golden` red at the replay tripwire.
  - The fixture goldens carry the fork too — `auth-hardening.json`'s three-way fork off `acme/platform#400` renders as
    `3 ready of 7` in `link-grid-repository.golden` with `#420`, `warehouse#87` and `infra#12` announced together, which
    is READY-as-a-set over `after` on a real page. **AC2's carried gap is closed with it**: `warehouse-rollout.json`'s
    `acme/warehouse#75` now declares `status: "merged"`, so the goldens finally have a declared-only row and can catch a
    provenance-glyph regression in either direction; `_link_grid_tripwire` pins the resulting unresolved count exactly
    rather than loosening it.
  - Commands run on this tree: `python3 -m pytest borg_core/manifest/test_core.py -k "fork or after or ready_set"`,
    `python3 -m pytest borg_core/link/test_grid.py -k "ready or draft"`,
    `python3 -m pytest borg_core/link/test_render.py -k "route or unsure or ungated or next_true or nobody"`,
    `bats tests/cli_contract.bats -f "renders the orchestrator context byte-identically"`, plus the three gates
    `make test`, `make lint`, `bats tests/` — all exit 0.
- [ ] **AC5 — Lifecycle skills author project manifests by default.** `/borg-plan` scaffolds a manifest,
      `/borg-link-up` updates row status, `/borg-assimilate` closes rows. None of it opt-in.
  - Verify: eval cases run each skill headless against a fixture repository and grade the emitted manifest; each
    positive case is paired with a negative case proving the conditional discriminates (see `evals/s4-k3/run.sh` E4/E5).
- [ ] **AC6 — e2e/eval harness MVP.** Generalize the `evals/s4-k3/run.sh` pattern into a reusable convention: a
      `make eval` target, deterministic cases green in CI, model-dependent cases behind `make eval-live` — which
      since decision (9) means the harness in the repository that OWNS the surface, not this one. Two
      clauses that sat here are deferred rather than gated, both because no clause this AC names could fail for
      them: the session-load case — a fresh session registers each skill exactly once and fires its hooks — goes to
      a parented directive (decision (6)), and the positive/negative pairing convention moves into the harness
      headers where it can be read against the cases it governs, with E2 as its named exception (decision (7)).
  - Verify: three gates, each pointing at something that actually runs. **CI** — `make test` green in the `python`
    job, which collects the offline E2a case (`borg_core/manifest/test_shell.py`'s `e2a` tests: the eight structural
    ref properties over a two-repository tree, plus an exact authored edge count), together with `bats tests/*.bats`
    in the `test` job — which also collects `tests/eval_floor.bats`, the oracle for ALL SIX floors below, ten
    cases pinning each floor in the firing direction and in the direction that proves it discriminates, per
    decision (5), and which that job now installs an importable pytest for rather than skipping past — and
    shellcheck over `evals/*/run.sh` in the `lint` job. **Local aggregate** — `make eval` green, offline by
    construction rather than by convention (`EVAL_ARGS ?= --skip-model --skip-network`), with the selection floor
    below armed. **On demand** — `make eval-live` green, the everything sweep that spends money and needs an
    authenticated `gh`. The deterministic eval evidence rides the EXISTING pytest and bats legs; per the build order
    no sixth CI job is added.
  - **A green run that selected or executed zero cases is a FAILURE, and every level is armed in this change.**
    Selection is one floor; execution is three. `make eval` fails when the `evals/*/run.sh` glob selects no harness.
    `evals/s4-k3/run.sh` then fails two ways: GLOBALLY, when it ran zero cases at all (`PASS + FAIL == 0`); and on
    the NETWORK mode, when `--skip-network` was absent and no network case executed. A MODEL-mode form sat here too
    and left with E4/E5 in decision (9); the relocated harness owns it. Dropping a skip flag is a REQUEST for that
    mode's sweep,
    and a run that asked for a sweep and performed none of it has failed at the thing it was asked to do. The two
    mode floors exist because the global one is satisfied single-handed by the one always-runnable offline case, so
    `make eval-live` — the "on demand" gate and the Ship Definition's one required run — reported SUCCESS at exit 0
    on a machine with neither `gh` nor `claude`, the entire live sweep absent. SKIPs still never gate a mode nobody
    asked for — a case whose inputs are absent on this machine has not failed. The floors exist because an empty
    gate and a passing gate print the same thing, which is why "deterministic cases green in CI" sat at zero members
    across three checkpoints unnoticed.
  - **Seven decisions ratified 2026-09-02; an eighth and ninth added 2026-09-03**, after the original verify
    clause was found unsatisfiable for a second and larger reason.
  - **(1) The CI clause names `make test`, not `make eval`.** NO CI JOB RUNS `make eval` — verified against
    `.github/workflows/test.yml`, whose five jobs are `lint` (shellcheck over `hooks/`, `lib/` and `evals/*/run.sh`),
    `test` (`bats tests/*.bats`), `python` (`make lint` + `make test`), `viz` (`make lint-viz` + `make test-viz`) and
    `contract-macos` (`bats tests/cli_contract.bats`). A clause naming a target no job invokes cannot go red, so it
    was never evidence of anything — and it is the reason that SURVIVES fixing the flag, which is why repairing only
    the flag would have left the clause exactly as unfalsifiable as it already was. Step 6 of the corrected build
    order in `.borg/checkpoints/2026-09-02-1309.md` also forbids a sixth CI job, because all three deterministic legs
    are already collected: bats by `test`, `borg_core` pytest by `python`, merge-tree pytest by `viz`. So the
    deterministic eval evidence has to ride a leg that runs, which is what makes E2a a pytest rather than a shell
    case.
  - **(2) `make eval` / `make eval-live`, not `make eval --skip-model`.** make's getopt consumes any leading-dash
    word anywhere in argv before a goal is built, so the flag never reaches a recipe and that invocation exits 2
    whatever the Makefile contains; a make VARIABLE is the only form that gets through, and `EVAL_ARGS` is the
    extension point because each harness takes its own flags. The ordering is a deliberate choice, not a
    convenience, and the split is OFFLINE versus EVERYTHING rather than model-free versus full: `make eval` defaults
    `EVAL_ARGS` to `--skip-model --skip-network` and `make eval-live` clears both, so the short target reaches
    neither a model nor the wire. It took the SECOND flag to make that true. Under `--skip-model` alone the target
    this plan calls the safe one still shelled one `gh pr view` per declared ref in E2 and fanned `borg recon` over
    the github adapter in E3, so a transport failure came back as "N unresolved rows" — a red gate blaming typo'd
    manifest data for a dropped connection, which is the conflation E2's own comment already forbids for the 401
    case. Only with the pair in place does the rule below describe the tree rather than merely assert itself: the
    target a CI clause names must not be the one that reaches the network, or CI acquires a network dependency by
    default and the offline guarantee becomes a matter of remembering a flag.
  - **(3) The floor is armed at both altitudes, and the execution altitude is mode-aware.** Selection is the
    Makefile's — the `evals/*/run.sh` glob selecting no harness is a failure, guarded on the GLOB rather than on
    `[ -d evals ]`, since with no nullglob a directory holding no `run.sh` passes a directory test and then hands
    the literal pattern to bash. Execution is `run.sh`'s, in the global and per-mode forms above — two modes since
    decision (9), not three. Arming the
    execution altitude required giving the harness one case that runs WHEREVER THE DEV TOOLCHAIN IS INSTALLED,
    which is what E2a is for — every pre-existing case skips without an authenticated `gh`, a second repository, or
    `claude` on PATH, and a floor nothing can satisfy is a permanent red, not a gate. "One case that runs on ANY
    machine" was this decision's first wording and it overstated the case: E2a needs pytest importable, and pytest
    is a third-party dev dependency that is NOT on this repository's ambient PATH — the toolchain lives in a local
    virtualenv that `make lint` and `make test` need just as much, since they invoke `coverage`, `ruff`, `mypy` and
    `pylint` bare. E2a's precondition is therefore exactly the one `make test` already carries, no weaker and no
    stronger, which is the narrower and honest claim. **And narrower again than "the toolchain is on PATH", because
    the harness RESOLVES ITS INTERPRETER BY PATH rather than assuming its caller exported one**: a
    `BORG_EVAL_PYTHON` override first, else the repository's own `.venv/bin/python` when that file is executable,
    else bare `python3`. So E2a RUNS on the machine of record with the virtualenv unactivated — measured in one
    shell, where `python3 -c "import pytest"` raises `ModuleNotFoundError` and the harness on the very next line
    reports `PASS E2a contract: pytest green (15 of 15 executed as passes)`, because the middle rung found the
    venv. (That line read `pytest green (15 tests)` when this decision was first written; the executed-outcome
    floor in decision (4) reworded it, and the quote is re-measured here rather than left to describe a harness
    that no longer exists.) It SKIPs only when the RESOLVED interpreter cannot import pytest, and the reason names
    that interpreter — this file's one vocabulary for an absent input. Forcing the resolution down to the
    pytest-less rung with `BORG_EVAL_PYTHON=python3` is the negative and the toolchain-less checkout in miniature:
    E2a skips, the run reports `0 pass, 0 fail, 3 skip`, and the global execution floor then fires and correctly
    reports that nothing was verified, which is the right answer for that machine and is not a green.
  - **(4) E2a is one implementation with two callers, and its gate has THREE doors.** pytest owns the assertions —
    `borg_core/manifest/test_shell.py`'s `e2a` tests, with the negatives that move the numbers (two manifests sharing
    one ref, a row added or removed), without which the authored counts are unfalsifiable by their own fixture.
    `evals/s4-k3/run.sh` calls that same `-k e2a` selection rather than restating them, so the CI leg and the
    harness cannot drift. A `-k` selection is a CONTRACT WITH THE TEST NAMES, and such a contract can be broken in
    three different sizes: the gate can be EMPTIED by renaming every test, SHRUNK by renaming some of them, and
    HOLLOWED without renaming anything at all. **The COUNT FLOOR is the live guard against the first two, partial
    or total.** The harness collects the selection with `--collect-only`, counts node-id lines, and fails when the
    count is under an authored minimum of 15 — not a guess, but what `--collect-only` reports for this selection
    today (`15/102 tests collected (87 deselected)`). It names the SHORTFALL, so a total rename reads
    `selected 0 of 15 authored` and a fourteen-of-fifteen rename reads `selected 1 of 15`: one mechanism, both
    sizes. The partial size is the one a non-zero floor could never see — renaming fourteen leaves `-k e2a`
    selecting one, pytest exiting 0, and the case printing PASS over a gate that has lost all but one assertion.
    **THERE IS NO rc-5 ARM, AND ONE MUST NOT BE ADDED BACK.** The count floor runs FIRST and the pytest RUN sits
    in its else-branch, so a selection that would make pytest exit 5 (no tests selected) has already failed the
    count and never reaches a run — measured by forcing the collection down to one node, which prints the count
    floor's FAIL and no pytest line at all. The arm was unreachable for every value the minimum can hold, and no
    oracle could ever cover it (the count-floor case can only assert its string is ABSENT), so it was deleted
    rather than reworded a third time; `evals/s4-k3/run.sh` says so at the floor. An rc 5 that arrives anyway means
    the whole selection was renamed BETWEEN the two pytest invocations, milliseconds apart — a race, not a
    control-flow path — and the generic `pytest exited N` arm still reports it as a FAIL with the rc named and an
    evidence file reading "no tests ran". That shape is REPORTED, not discriminated, and the difference is only a
    nicer sentence in an unobservable window. **The third door is
    HOLLOWING, and the count floor structurally cannot see it, because a skipped test is still a COLLECTED test.**
    Measured this round against the harness as it stood before the fix: with every selected test carrying a skip
    marker, pytest printed `15 skipped, 87 deselected` and exited 0, the collection still counted 15, and the
    harness's whole stdout plus its exit status were identical to a real pass — `PASS E2a contract: pytest green
    (15 tests)`, rc 0, diffed against the control in the same shell. **What closes it is the EXECUTED-OUTCOME
    FLOOR, and it sits inside the rc-0 arm** — the only place it is needed, since a failure or an error already
    forces rc non-zero and keeps its own reason. The verdict reads `--junit-xml` rather than `-q`'s summary,
    because the summary's wording is pytest's to change while the XML's element shape is a published contract: a
    `<testcase>` counts as executed-as-a-pass iff it carries no `skipped`, `failure` or `error` child, and the case
    fails when that count comes in under the number COLLECTED — so ONE drifted marker trips it, not merely a
    wholesale hollowing. Two details are load-bearing. The count is CLASSIFIED before it is compared (a `case` over
    digits, never `-lt` on an unknown value), because the count floor above learned that the expensive way:
    `[ "" -lt 15 ]` is an error rather than a false, and `if` reads it as "not less than". And
    `-o xfail_strict=true` closes the one door the XML alone cannot see, since a non-strict xpass renders
    byte-identically to a pass while under strictness it becomes a `<failure>` at non-zero rc. Re-measured against
    the same mutant after the floor landed: `FAIL E2a contract: 15 collected but not all executed (0 passed, ...)`
    at rc 1, beside the control's `PASS E2a contract: pytest green (15 of 15 executed as passes)` at rc 0. So the
    three doors are closed by TWO mechanisms, not three: emptied and shrunk are both the count floor's, hollowed is
    the outcome floor's, and the collect-versus-run race is reported by the generic arm rather than owned by one.
    What E2a deliberately does NOT cover: whether a ref RESOLVES on GitHub
    is one bit per ref that no committed artifact can establish, since a frozen recording asserts only "it existed
    at T", so that claim stays in E2 behind `make eval-live`.
  - **(5) A floor with no oracle is the defect class the floor exists to prevent — so the floors are COUNTED here,
    and ALL SEVEN have one, each in both directions.** The principle first, and it is the reason for the arithmetic
    that follows: as first shipped neither the selection nor the execution floor was falsifiable — strip the
    Makefile's `found`-at-zero branch or `run.sh`'s `PASS + FAIL == 0` branch and every gate in this repository
    stays green, because no CI job invokes an eval target, no other bats file executes anything under `evals/`, and
    shellcheck models syntax rather than exit status. That is the same "absence and success print the same thing"
    shape the floors were added to catch, reproduced one altitude up, with this plan asserting both were armed and
    nothing in the tree able to contradict it. The repair for that is not another assertion of coverage, so: there
    are SIX floors across two artifacts — the Makefile's SELECTION floor and its `EVAL_ARGS` validator (a floor
    in all but name, since `-h`/`--help` reaches the harness's usage exit before a counter moves and is therefore a
    green run of nothing arriving through the documented extension point), plus `run.sh`'s GLOBAL execution floor,
    NETWORK-mode floor, E2a COUNT floor and E2a EXECUTED-OUTCOME floor. **It was SEVEN until 2026-09-03**: the
    MODEL-mode floor left this tree with E4/E5 — see decision (9) — and a floor no remaining case can fire is a
    permanent red rather than a gate, which is decision (3)'s own rule applied to its own artifact.
    **`tests/eval_floor.bats` is TEN cases and covers all six** — `bats tests/eval_floor.bats` prints `1..10`
    and ten `ok` lines, and that file's own header enumerates the same six floors at three altitudes. **That
    header said TWELVE while bats printed `1..13`**, in opposite directions, for as long as an unrelated
    thirteenth case had been landing without updating it or this paragraph; both are now counted in one place
    per artifact. Three
    floors get a case per direction: SELECTION fires on both shapes the recipe's own comment argues about (no
    `evals/` at all, and an `evals/` that exists but holds no `run.sh`) and holds for one trivial harness that
    passes; the GLOBAL execution floor fires over the `evals/*/run.sh` glob with every optional input hidden behind
    a positively-named binary allowlist and holds on the same offline invocation once handed an interpreter that
    can import pytest; and the NETWORK-mode floor fires on the invocation that drops exactly that one skip flag —
    so that mode's sweep IS requested — with `gh` hidden, and holds on the same invocation against a stub and one
    case it can execute. The remaining three carry both directions inside a SINGLE case, because for them the
    negative is a one-token edit of the positive and a discriminator living in a neighbouring case is not a
    discriminator for this one: the `EVAL_ARGS` validator refuses `--help` and a metacharacter word BY NAME while
    asserting the harness never ran at all, then admits an EXPLICIT offline value — distinct from the default the
    selection negative exercises, since a typed override is the only shape that reaches the validator's loop with
    something a USER wrote (the exported default is validated by the same loop, which is why the admitting half is
    needed at all: without it the validator would be credited for refusing everything); the COUNT floor fails a
    selection one test short naming both numbers, then exits 0 on the same synthetic sandbox one test richer; the
    OUTCOME floor fails a full selection carrying one collected-but-skipped test, then exits 0 on the same sandbox
    without the marker. The twelfth case is nobody's floor: it oracles the `$REPO` checkout guard sitting in front
    of the harness's `rm -rf "$OUT"`, in both directions, with a canary planted where `$OUT` would be — the one
    invariant in this change whose failure mode is destructive rather than merely silent, and equally unread by
    anything until that case landed. So no floor is credited for an artifact that merely always fails, and every
    case that executes a harness loops the glob rather than naming `s4-k3` and fails when the loop was vacuous, so
    a future harness that forgets to self-police turns the oracle red the day it lands. It rides the CI legs that
    already run: the `test` job's `bats tests/*.bats` glob collects the file by existing, so no sixth job is added,
    per decision (1).
    **AND THE ORACLE WAS ITSELF INERT IN CI — the same principle recursing once more, on its own fix.** The seven
    cases that must EXECUTE a harness each need an interpreter that can `import pytest`; the only job that collects
    the file installed `zsh`, `jq` and `fzf` and no Python toolchain at all, and a bats `skip` prints `ok`. So that
    job reported every case green having executed only the ones that need no interpreter, and deleting a mode floor
    would have turned nothing red there — a suite announcing coverage it was not providing, on the very leg the
    verify clause above cites as evidence. The repair is two-sided, and it keeps decision (1) intact: **NO SIXTH
    JOB.** In `.github/workflows/test.yml` the EXISTING `test` job gains a `Set up Python 3.14` step and an
    `Install dev toolchain (tests/eval_floor.bats needs an importable pytest)` step running
    `pip install --group dev` — the same action version, interpreter and install invocation as the `python` and
    `viz` jobs, because three jobs installing the dev group three ways is how they drift — so its steps are now
    checkout, apt deps, python, dev toolchain, bats, `bats tests/*.bats`, and that file still declares exactly the
    five jobs decision (1) enumerates: `lint`, `test`, `python`, `viz`, `contract-macos`. That supplies the
    premise; the other side makes a MISSING premise loud. `_python_with_pytest` no longer calls `skip` — it prints
    `premise broken: no interpreter with an importable pytest -- run 'pip install --group dev'` and returns
    non-zero, and a grep for a `skip` call anywhere in the file now finds none. A gate that yields to a missing
    dependency is the thing this decision exists to remove, so the trade is red-and-actionable over
    green-and-empty.
    **The hand runs are HISTORICAL — evidence from the round before the oracle existed**, kept because they are
    what decisions (3) and (4) measured their numbers against, and superseded as gates by cases 3 and 6–11. With
    the network binaries hidden and a working interpreter supplied: no flags at all exited non-zero on "the network
    sweep was requested but no network case executed", `--skip-network` alone exited non-zero on the model twin,
    both over a run that printed "1 pass, 0 fail, 4 skip" — the exact shape that used to exit 0; forcing the
    collection below its minimum exited non-zero naming the shortfall; skip-marking the whole selection exited
    non-zero naming what was collected against what executed, against a control that passed; and
    `make eval EVAL_ARGS=--help` and `make eval EVAL_ARGS='--bogus; true'` were both refused, by name, before any
    harness ran. A hand-run is evidence for a checkpoint and not a gate, which is why all five are now cases in
    that file rather than a paragraph here.
  - **(6) The session-load case is DEFERRED to a parented directive, and the criterion no longer asks for it.** It
    sat in the criterion body from the first draft — "a fresh session registers each skill exactly once and fires
    its hooks" — and nothing in the tree implements it: a grep for `session-load` over `evals/`, `tests/`, the
    `Makefile` and `docs/plans/directives/` returns NOTHING, and every hit anywhere is in this file — stated that
    way round on purpose, so the sentence stays true as this plan gains prose about the deferral. So every gate
    this AC names could go green with the clause wholly unbuilt, which is decision (1)'s finding one level down: a
    requirement no clause can fail for is not a requirement, it is a description. The two honest
    exits are a gate or a deferral, and a gate is unavailable — the only artifact that could check it is a
    session-lifecycle harness that does not exist, and naming an artifact nothing runs is exactly the
    unfalsifiable clause decision (1) deleted. It is also the wrong SHAPE for this AC: every other case here is
    offline and deterministic or sits behind `make eval-live`, whereas this one needs a real session start, real
    hook dispatch and the installed skill set — a different harness, not a case in `evals/s4-k3/run.sh`, and one
    whose negative ("a skill registered twice") requires mutating an install. So it is filed rather than gated, in
    the same voice AC7 uses for the rename it defers: **FILED 2026-09-03** as
    `docs/plans/directives/2026-09-02-session-load-eval-skill-registration-and-hooks.md`, carrying a
    `*Parent plan:*` line back here. That discharges this decision. **It does NOT tick AC6, and the reason is the
    third verify gate rather than this clause** — see decision (8).
  - **(7) The pairing convention moves out of the criterion body for the same reason, and E2 is its named
    exception.** "Every positive case paired with a negative" sat beside the session-load clause and has the
    identical defect decision (6) rejects it for: no gate this AC names can go red for it. Nothing in the tree
    counts pairs or checks pairing, and giving it a gate would mean a harness declaring its own pair structure —
    meta-machinery whose failure mode is a stale declaration, which is the class this whole amendment exists to
    stop adding. It is also not universally satisfiable, and that is the more useful fact: E2 asks whether a
    declared ref RESOLVES on GitHub, a claim about the present state of a system this repository does not own, and
    its negative would have to be a ref that reliably does NOT resolve — an artifact nobody can commit, since a
    dead ref today may be a live one tomorrow. So pairing stays where it can be read against the cases it governs,
    in `evals/s4-k3/run.sh`'s header and in `tests/eval_floor.bats`'s, as a convention every case there does in
    fact honour; the criterion body no longer asks for what no clause can fail for. The distinction to keep: a
    convention documented next to its instances is checkable by a reader, while a criterion nothing gates is
    checkable by nobody.
  - **(8) The remaining blocker is `make eval-live`, and the model floor is what makes it visible.** Measured
    2026-09-03 on the machine of record with `claude` on PATH and `gh` authenticated: `make eval-live` exits **rc 2**
    reporting `2 pass, 0 fail, 3 skip` and `the model sweep was requested but no model case executed`. E2a passes, E2
    resolves all three declared refs live, and E3/E4/E5 all SKIP for want of a fixture repository — E3 and E4 need
    `BORG_EVAL_STILLPOINT`, E5 needs `BORG_EVAL_TROTH`, and both are unset. So the MODEL-mode floor fires and is
    RIGHT to fire: the third gate asks for the everything-sweep and the everything-sweep did not happen. This is the
    floor earning its place rather than a defect in it — the plan's own Risks section predicted exactly this ("the
    required run could be performed, reported green, and have executed not one model case"), and before the floor
    landed this invocation exited 0. **Two remaining actions, not one.** The checkpoint of 2026-09-03-0955 recorded
    filing the directive as the last thing standing between AC6 and a tick; that was incomplete. **RESOLVED the same
    day, and NOT the way this decision predicted** — see decision (9). The prescription here was "provision the two
    fixture repositories", which accepted the cases' own premise that they needed particular repositories at all.
    They did not: E3 needed *a* second manifest-bearing tree, E4 *a* manifest, E5 *a* repository without one, and
    the identity of all three was incidental to every assertion. Provisioning would have bought a green gate on one
    machine and left the same skip on the other two. The record is kept rather than rewritten because the wrong
    prescription is the instructive part: "the fixture is missing" and "the case should not have named a fixture"
    look identical from inside a skip message.
  - **(9) The live cases stop naming repositories, and two of them stop living here.** Ratified 2026-09-03 after
    decision (8)'s blocker turned out to be a premise rather than a shortage. Three changes, one principle: a case
    may not require a repository that is not in the tree that owns it.
    **E3 stages its second repository from committed fixtures** — two directories and two hand-authored manifests,
    no `git init` needed since `discover` only globs `.borg/programs/*.json` — and its threshold becomes an
    EQUALITY. `>= 14` was calibrated against whatever two live repositories held on the day it was written: a
    number nobody could re-derive, drifting silently as those repositories changed, and satisfied by a fixture
    producing 200 edges as readily as one producing 14. The authored total is 15, verified against BOTH manifest
    implementations before being written down, and they agree on the total while disagreeing on two members —
    `borg_core` honours `after:` and emits `platform#903 -> warehouse#912` and `platform#902 -> warehouse#923`,
    `merge-tree` ignores it and emits the lane-consecutive pair instead. That is decision (3) of AC7 reproduced in
    nine rows, and it is why the number is safe across AC7's repoint: the count survives, only the membership
    moves. Mutation-verified — one extra row reads `declared edge count 17 != authored 15`.
    **E4/E5 RELOCATE to `claude-plugins/evals/pr-description/`**, because they grade `/pr-description`, which this
    repository does not own; a red here could only ever have named a defect in another tree. Both are synthesized
    from `git init` there and both PASS, which is the substitution E5's own comment had already prescribed and
    deferred for want of a tree that could verify it. **The MODEL-mode floor goes with them**, since a floor no
    remaining case can fire is a permanent red — decision (3)'s rule turned on decision (3)'s own artifact — and
    `--skip-model` stays ACCEPTED AND INERT because `EVAL_ARGS` passes it to every harness and the unknown-flag arm
    exits 2. The relocated harness carries ONE floor rather than a global-plus-per-mode pair: every case there is a
    model case, so `--skip-model` requests nothing, and a run asked for nothing that did nothing has not failed.
    **The oracle moved too, and one invariant with it.** `tests/eval_floor.bats` drops from thirteen cases to ten;
    the guarded-array case is not deleted but INHERITED by
    `claude-plugins/evals/pr-description/floor-tests.sh`, the harness that still expands an optional prefix, and
    that file's own guards are oracled there in both directions with no model at all — mutation-verified, deleting
    the model floor takes it from 8 ok to 7 ok, 1 fail. It is wired into that repository's existing `evals-harness`
    job as one step, no new job, so the relocated cases are not another gate nothing invokes.
    **The measured result is the point**: `make eval-live` was rc 2 on `2 pass, 0 fail, 3 skip` and is now rc 0 on
    `3 pass, 0 fail, 0 skip` — no skips, on a machine holding neither stillpoint nor troth, which is the state all
    three machines are now in by construction rather than by luck.
- [ ] **AC7 — "Program" is gone, and nothing breaks.** Eliminated from user-facing surfaces, skills, help text, and
      `merge-tree/`. The repository-side rename is filed as a parented directive, not executed. Suites green and
      coverage holds its floor.
  - Verify: `grep -ri program` over the COMMANDS section of `borg help`, over `skills/`, and over `merge-tree/`
    returns nothing; the directive file exists with a `*Parent plan:*` line; `make test` green at `--fail-under=90`;
    `bats tests/` green.
  - **Three decisions ratified 2026-08-31**, after the original verify clause was found unsatisfiable as written.
  - **(1) The REMOVED block is excluded from the grep, and the clause above says so.** The original read
    "`grep -ri program` over help text" and could never pass: this repo retires a verb by moving it to a REMOVED
    tombstone in `borg help`, which is test-enforced —
    `contract: recon is gone from COMMANDS and named in REMOVED (AC1)` asserts `recon` is absent from COMMANDS *and*
    present in the REMOVED block. Retiring `program` correctly therefore puts the word back into help text. The
    tombstone exists so a user typing a dead verb gets a pointer rather than `unknown command`, which is worth more
    than a literal grep. Scoping the grep to COMMANDS keeps the intent — the retired word is off the live command
    surface — without demanding the convention be broken for one verb.
  - **(2) `borg program` becomes `borg chain`, not `borg project`.** The Vocabulary maps program → project, but AC7
    defers the `project` → `repository` rename, and `cmd_program` reads `jq -r '.projects[].path'` where `project`
    means *repository*. `borg project` would ship a verb whose name means workstream and whose body means
    repository. `chain` sidesteps both senses and matches what `borg link` already prints in `▸ CHAINS`. It is also
    a RENAME, not a deletion: `contract: borg help is net one command shorter than at plan start (AC1)` asserts the
    COMMANDS count is exactly `25`, so deleting the verb turns it red, while renaming leaves the count intact. Four
    contract tests invoke the verb by name and move with it.
  - **(3) `merge-tree/programs.py` is RETIRED into `borg_core/manifest/`, not renamed.** `core.py`'s own docstring
    says "Retiring one of the two copies is AC7's problem, not this module's." The two have diverged — the
    merge-tree write gate is weaker on `after`, the borg_core read gate is weaker on `gate.kind`, so a manifest the
    writer accepts can be silently unreadable by the reader. Renaming preserves that. Retiring erases the
    occurrences instead of relabelling them, and it is a prerequisite for the `borg reconcile` work filed in
    `docs/plans/directives/2026-08-31-shim-architecture-for-borg-and-employer-plugins.md`: shipping an automated
    writer on top of an unresolved reader/writer disagreement runs that risk on every timer tick rather than only
    when someone hand-edits. Measured cost: 292 occurrences across 44 tracked files, and 343 tests covering
    `programs.py` at 98% and `coordinator.py` at 95% move with it.

## Scope Boundaries

- NOT building: S1 `borg show`, and the `--md` / `--html` output modes. ANSI-to-stdout only. Conscious call — `--md`
  exists to hand a document to nvim, which needs S1, which is a new verb, and the terminal already answers
  "what's in flight."
- NOT building: the `project` → `repository` internal rename. AC7 files it — filed 2026-08-31 as
  `docs/plans/directives/2026-08-31-project-to-repository-rename.md`, which RE-MEASURED the scope at **3142
  occurrences across 97 of 139 tracked code files**, not the ~500 across 57+ estimated here. Plus
  the registry schema key and `.borg-project` markers.
- NOT building: infoviz Track 6 as a blocker. The one reading with teeth here is Ghoniem et al. (past ~20 vertices,
  matrices beat node-link except on path-finding); live manifests are 3 and 14 rows on a path-finding task, so the
  evidence most likely confirms the specced grammar. An hour of reading, not a phase.
- NOT building: evals beyond the three lifecycle skills in AC5.
- NOT building: AC6's session-load case. AC6 files it — filed 2026-09-03 as
  `docs/plans/directives/2026-09-02-session-load-eval-skill-registration-and-hooks.md`. See AC6 decision (6): it
  needs a session-lifecycle harness that does not exist, and a criterion clause naming one would be unfalsifiable.
- If done early: ship what we have, don't expand scope.

## Ship Definition

Committed to `main` + `make test` green + `bats tests/` green + `make eval` green with the zero-selection floor
armed + one `make eval-live` run on demand + manual `borg link` smoke in both repository and orchestrator context +
`borg help` text updated.

## Timeline

Target: 4 sessions. AC6 is a session on its own; AC1–AC5 carry automated verification rather than manual smoke, which
is most of the increase over the original estimate.

**Work begins 2026-08-25** — weekly credits are nearly exhausted as of 2026-08-24.

## Risks

- **Out-of-window decay is the most likely way this fails.** Manifests are timeless; recon is windowed, and the
  intersection decays fast — a 4-repository project measured 13 of 14 declared endpoints dangling one day later on a
  14-day window. AC3 fixes correctness, but if the targeted fetch is slow, repository-scoped `link` loses the 2.7s
  that makes it reflexive. Measure fetch cost early; protect it by cutting elsewhere.
- **Empty-manifest failure mode.** Only two manifests exist and both are hand-authored. If AC5 is weak, `borg link`
  renders nothing and reads as broken. The authoring path is load-bearing, not the renderer.
- **`gate.kind` is hand-set.** Yours-vs-mine is exactly as good as that field. A mis-set gate routes a human decision
  to an agent silently — a wrong answer, not a missing one. AC5's evals are the only thing that would catch
  systematic drift.
- **Eval flakiness.** Model-dependent cases fail intermittently. `run.sh`'s `--skip-model` flag still holds them
  back, and the invocation that actually runs them is `make eval-live`. The sharper version of the risk: CI never runs
  them AT ALL — no job invokes any eval target — so their only gate is someone remembering. The Ship Definition asks
  for exactly one such run, but asking is not forcing, and it was not forcing the model cases to run: until the
  model-mode execution floor landed, `make eval-live` exited 0 on a machine with no `claude` on PATH at all, so the
  required run could be performed, reported green, and have executed not one model case. The mode floor is what
  forces them now — request the model sweep, execute none of it, and the run exits non-zero with that reason named
  on stderr.
