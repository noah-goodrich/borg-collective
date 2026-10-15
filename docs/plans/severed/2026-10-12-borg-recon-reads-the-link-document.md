> Dropped 2026-10-12: `borg link` folds the same fan-out into its own document, so recon phase 5b and this directive were not built.

# Directive: /borg-recon synthesizes the borg link document instead of running its own sweep

*Filed: 2026-10-12 · Status: Proposed, NOT BUILT (Noah decided 2026-10-12 to defer) · Owner: Noah*
*Split out of Phase 5b of `docs/plans/assimilated/2026-08-10-briefing-fallback-and-summary-provenance.md`, where it was filed 2026-08-26.*

**tl;dr** — `/borg-recon` is a human briefing that runs its own sweep through `borg recon --json`, on its own time window, and advances `$BORG_DIR/recon/last-run` as a side effect. `borg link` never touches that marker. This directive makes `/borg-recon` a synthesis layer over `borg link`'s document so there is one input and no hidden state change. It is filed and deferred, not scheduled.

## Why

AC1 retired the `recon` verb but kept the engine, because `borg recon --json` has real machine consumers. One of them, `skills/borg-recon/SKILL.md`, is itself a human-facing briefing invoked as `/borg-recon`. So `borg help` says recon was retired because there is nothing a human still needs it for, while a skill renders the by-project digest that AC1 retired.

The two surfaces disagree, and one of them mutates state the other is asserted never to touch:

- `borg link` uses a fixed 90-day window (`grid.DEFAULT_SWEEP_WINDOW_DAYS`, overridable via `BORG_LINK_SWEEP_WINDOW_DAYS`) and never writes `$BORG_DIR/recon/last-run`. That is pinned twice, by `borg_core/link/test_grid.py` and by the AC1 cache case in `tests/link_sweep.bats`.
- `/borg-recon` goes through `borg recon --json`, whose window is recon's since-ladder (explicit, then newest checkpoint mtime, then the last-run marker, then 24h), and it ADVANCES the marker.

So running `/borg-recon` changes what the next `borg recon --json` sees, on a window `borg link` does not share. Two answers to one question, one with a persistent side effect on the other's inputs.

Already declared, not fixed: `borg help` and `docs/cheatsheet.md` title `/borg-recon` as "cross-source synthesis over `borg recon --json` (`borg link` is the front door)", not as the morning link-up. The skill itself is unchanged and still works.

## The change

Once `borg link`'s document is the single input, `/borg-recon` becomes a synthesis layer over THAT document (contradictions, Yours-vs-Mine, kickoff batch) rather than a parallel sweep with its own mark. This is the same shape as Phase 5 of the old directive, which routed `--brief` through the document (`docs/plans/assimilated/2026-08-27-fold-brief-into-the-document.md`). It shares the routing decision with Phase 5 and was always ordered after it; Phase 5 is met, so nothing blocks it except priority.

## Deferred, on purpose

Noah decided on 2026-10-12 not to build this now. The declared-not-fixed state above is the interim: the skill works, it is not billed as the default entry point, and the side effect is documented here. Revisit if the marker advance causes a visible wrong answer.

## Acceptance criteria

- [ ] `/borg-recon` synthesizes `borg link`'s document rather than running its own sweep on its own mark. Verify that a `/borg-recon` run leaves `$BORG_DIR/recon/last-run` unchanged, the mirror of the AC1 cache case's existing assertion for `borg link`.

## Origin

`docs/plans/assimilated/2026-08-10-briefing-fallback-and-summary-provenance.md`, Phase 5b.
