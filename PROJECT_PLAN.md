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

- [ ] **AC1 — One front door, context-scoped, always a clean read.** In a repository, `link` sweeps that repository
      (~2.7s measured); in the orchestrator, it sweeps all (~12.5s measured, 13 repos). No cache, ever — a clean read
      every time. `--local` is the only opt-down. `recon` retires as a human-facing verb; no new verbs are added.
  - Verify: bats asserts `borg help` is net one command shorter than at plan start, and that two consecutive
    `borg link` runs write no cache artifacts.
- [ ] **AC2 — The topological grid is the renderer, everywhere.** Vertical, rows as levels with time flowing down,
      columns as branches, box-drawing connectors, state glyphs, compact nodes with detail blocks below, ANSI to
      stdout by default with OSC-8 hyperlinks on refs. Repository and orchestrator contexts differ in breadth only —
      never layout, section order, or vocabulary.
  - Verify: golden-file snapshot test rendering both contexts from fixture manifests; one render entry point.
- [ ] **AC3 — Declared members outside the sweep resolve truthfully.** Any ref declared in a manifest but outside the
      current sweep window is targeted-fetched, never rendered `unknown`.
  - Verify: e2e case runs `borg link` inside one repository against a fixture manifest spanning several; asserts zero
    nodes render `unknown`.
- [ ] **AC4 — Rows drive "next" and "yours vs mine."** Sourced from `rows[].next` and `gate.kind`, never re-derived.
      READY = open AND every parent merged, announced as a set. Adds row-level `after: [refs]` so forks are
      expressible (lanes only express linear tracks).
  - Verify: pytest over the derivation against fixture manifests including a fork case and a negative case.
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
