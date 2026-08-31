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
- **"Program" is retired.** It does not appear in new code, output, skills, help text, or documentation. The
  repository-side internal rename (`project` → `repository`) is deferred to a parented directive; see AC7.

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
      `make eval` target, deterministic cases green in CI, model-dependent cases behind `--skip-model`, every positive
      case paired with a negative. Includes the session-load case — a fresh session registers each skill exactly once
      and fires its hooks.
  - Verify: `make eval --skip-model` green in CI; full `make eval` green on demand.
- [ ] **AC7 — "Program" is gone, and nothing breaks.** Eliminated from user-facing surfaces, skills, help text, and
      `merge-tree/`. The repository-side rename is filed as a parented directive, not executed. Suites green and
      coverage holds its floor.
  - Verify: `grep -ri program` over help text, skills, and `merge-tree/` returns nothing; the directive file exists
    with a `*Parent plan:*` line; `make test` green at `--fail-under=90`; `bats tests/` green.

## Scope Boundaries

- NOT building: S1 `borg show`, and the `--md` / `--html` output modes. ANSI-to-stdout only. Conscious call — `--md`
  exists to hand a document to nvim, which needs S1, which is a new verb, and the terminal already answers
  "what's in flight."
- NOT building: the `project` → `repository` internal rename. AC7 files it; ~500 occurrences across 57+ files plus
  the registry schema key and `.borg-project` markers.
- NOT building: infoviz Track 6 as a blocker. The one reading with teeth here is Ghoniem et al. (past ~20 vertices,
  matrices beat node-link except on path-finding); live manifests are 3 and 14 rows on a path-finding task, so the
  evidence most likely confirms the specced grammar. An hour of reading, not a phase.
- NOT building: evals beyond the three lifecycle skills in AC5.
- If done early: ship what we have, don't expand scope.

## Ship Definition

Committed to `main` + `make test` green + `bats tests/` green + `make eval --skip-model` green + one full `make eval`
run on demand + manual `borg link` smoke in both repository and orchestrator context + `borg help` text updated.

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
- **Eval flakiness.** Model-dependent cases fail intermittently. Keeping them behind `--skip-model` protects CI but
  means they only run when someone remembers; the ship definition forces one run.
