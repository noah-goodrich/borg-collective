# Directive: The Directive-State Deriver

*Filed: 2026-08-20 · Status: Proposed · Parent: 2026-08-20-communication-program.md*

**tl;dr** — 36 of 109 open directives are already done and nothing records it; 97% of checkpoints restate
plan position by hand. Derive every directive's status mechanically from evidence git already holds, and
surface it where mornings start.

## Problem

The 2026-08-20 completion audit measured the board lying in one direction: of 76 non-backlog open
directives, 36 (47%) were verifiably shipped — merged PRs, artifacts on disk — with unflipped checkboxes
and unarchived files. Establishing the truth took 14 agents applying a rubric to git history. That rubric
is mechanical; nothing runs it.

## Solution

Mechanize the audit rubric as a borg_core module and make `borg link` its consumer.

- **D1 — the classifier.** Per open directive: status ∈ {shipped-unarchived, in-flight, stalled,
  filed-only} from git last-touch, checkpoint slug mentions, merged-PR references, and checkbox counts.
  The 2026-08-20 audit's rubric (14-day activity window) is the spec; its blind-recount boundary cases
  (85% label agreement) define the honest uncertainty band — borderline items get flagged, not forced.
- **D2 — surfaced in `borg link`.** Overview gains a derived-status glance strip per project; deep dive
  shows per-directive status with one evidence line each. Landing region, per the house grammar.
- **D3 — the reconciliation report.** `shipped-unarchived` items listed with their evidence and a
  one-command archive proposal (`git mv` to assimilated/). Proposal only — a human moves files.
- **D4 — recon since-mark fix.** `resolve_since` passes relative forms (`30d`) to adapters verbatim; gh
  silently sweeps zero. Parse Nd/Nh/Nw to ISO before fan-out, or reject loudly. Every derived view feeds
  on recon; a silent-zero sweep poisons all of them. (borg_core/recon/core.py:46, shell.py:116.)

## Goals

- Zero hand-restated plan position needed to answer "what state is this directive in."
- The 36-item shipped-unarchived backlog reaches zero via D3 proposals within two weeks of shipping.
- Checkpoints shrink: the template drops state restatement once the deriver carries it.

## Non-Goals

- No auto-archiving, no auto-flipping checkboxes without a human command. Proposals only.
- Not the cross-repo program layer (#158's manifests) — this derives per-directive status, not edges.
- Not a new store: derived output is a view, regenerated, stable path, overwritten in place.

## Alternatives Considered

- **Keep hand-flipping checkboxes**: measured failure — 27% checked against ~double real completion;
  0/44 in a fully-shipped project. Volunteered capture rots.
- **LLM-judged status instead of a rubric**: rejected; the audit's mechanical rubric reproduced at 100%
  file-set agreement and 85% labels, and judgment-based capture is the cairn failure shape.
- **GitHub Projects as the state store**: rejected in the umbrella (another volunteered surface).

## Acceptance criteria

- [ ] AC1 Classifier output matches the 2026-08-20 audit's classifications on the audit's own corpus
      snapshot (fixture from `audit.json`), boundary cases flagged not forced.
- [ ] AC2 Tests drive the production derivation path (git/checkpoint reads), never fixture-supplied
      statuses — per `reference_test_supplies_derived_value`.
- [ ] AC3 `borg link` overview and deep dive carry the derived status; goldens regenerated.
- [ ] AC4 `borg recon --json --since 30d` sweeps correctly (pytest on the resolve path) or exits loudly.
      (`--json` since 2026-08-26: `recon` retired as a human verb, so `--since` alone now dies at the
      dispatch arm. The pytest is on `resolve_since` and is unaffected; only the CLI example moved.)
- [ ] AC5 D3 report proposes the correct archive move for a known shipped-unarchived fixture.
- [ ] AC6 Full bats suite + macOS contract leg green.
