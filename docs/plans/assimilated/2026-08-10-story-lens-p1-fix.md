# Project Plan: Story-Lens P1 Fix + Branch Consolidation
*Established: 2026-08-10*
Shipped: 2026-08-11

*All 7 criteria verified 2026-08-10. Code landed in PR #104 (squash-merged as `2f8d22a`); the
empirical-test resolution record is PR #111. Verification evidence: C1/C2 source greps, C3 renderer
exit 0 at 254,377 bytes, C4 single-PR check + `rev-list` count 5, C5 doc table, C6 bats 503 pass /
0 fail matching baseline, C7 `grep -ri cairn merge-tree/` clean after prose correction.*

## Objective
Land the remaining infoviz Phase-1 empirical-test fix (P1: make the Story-Lens state meter's length
comparable across projects) and consolidate `feature/hub-story-lens` into the existing PR #104 so a single
PR carries the whole `merge-tree/` graduation instead of two branches racing to add the same files.

## Context
`docs/infoviz/research/2026-07-30-perception-encoding/04-empirical-test.md` prescribed three fixes to the
Story-Lens hub. Fixes 1 (P4/P3 salience swap) and 3 (P6 animated zoom) landed in `f07d103`. Fix 2 (P1) did
not: `render_graph.py:454` sizes meter segments with `flex-grow:<count>` inside a fixed-width track, so every
project's meter renders the same total width and cross-project comparison is meaningless.

`feature/hub-story-lens` is a strict superset of PR #104's branch (`feature/graduate-merge-tree-hub`, tip
`fc7b07b`) — that tip is an ancestor of lens, which is 4 commits ahead. Both add `merge-tree/`, which does not
exist on `main`.

## Acceptance Criteria
- [x] C1 — Meter total length is proportional to the project's total workstream count, with a named minimum
      floor so single-item projects keep a visible mark. The P2 numeric labels remain on every non-zero state.
  - Verify: `grep -n 'METER_MIN_WIDTH_FRAC\|MAX_METER_TOTAL' merge-tree/render_graph.py` returns the named
    constant and its use; `grep -n 'meterlabs' merge-tree/render_graph.py` still shows the label row.
- [x] C2 — The max-total is computed once in Python and emitted as a JS const, not recomputed per card.
  - Verify: `grep -n 'MAX_METER_TOTAL' merge-tree/render_graph.py` shows one Python-side computation and one
    `json.dumps` emission near the existing `STATE_ORDER` const block (~line 207); no `Math.max` over all
    projects inside `meterHtml`.
- [x] C3 — Renderer runs clean against the live state dir and emits a non-trivial `graph.html`.
  - Verify: `python3 merge-tree/render_graph.py --out /tmp/graph-smoke.html` exits 0 and
    `cat /tmp/graph-smoke.html | wc -c` is > 200000.
- [x] C4 — PR #104 is the single vehicle: `feature/graduate-merge-tree-hub` contains the 4 lens commits plus
      the fix-2 commit, and no second PR exists for `merge-tree/`.
  - Verify: `gh pr list --state open --json number,headRefName` shows exactly one PR touching `merge-tree/`;
    `git rev-list --count origin/feature/graduate-merge-tree-hub ^fc7b07b` returns 5.
- [x] C5 — The empirical-test doc records fix 2 as resolved, so the Phase-1 record matches reality.
  - Verify: `grep -n -i 'resolved\|applied' docs/infoviz/research/2026-07-30-perception-encoding/04-empirical-test.md`
    shows a resolution note against all three fixes with commit refs.
- [x] C6 — Regression: the existing bats suite passes unchanged.
  - Verify: `bats tests/` exits 0 with no new failures vs. the pre-change baseline.
- [x] C7 — The open question gating PR #104 is answered: the renderer has no cairn dependency.
  - Verify: `grep -ri 'cairn' merge-tree/` returns nothing.

## Scope Boundaries
- NOT building: a bats/pytest suite for `merge-tree/` — the fixtures exist but wiring a harness is its own plan.
- NOT building: option (b) from the empirical test (a separate shared-baseline mini-bar). One dimension on the
  existing mark only; a second mark fights the P4 fix that just landed.
- NOT doing: marking PR #104 ready-for-review or merging it. Noah's call, not this plan's.
- If done early: ship, don't expand.

## Ship Definition
Fix-2 commit on `feature/graduate-merge-tree-hub`, pushed, PR #104 reflecting all 5 commits, CI green,
renderer smoke test passing. PR stays in draft pending Noah's review.

## Timeline
Target: this session.
Estimated effort: ~1 hour. The code change is one function plus one constant; most of the work is the branch
consolidation and verification.

## Risks
- **The floor constant is a judgment call.** Too high and the proportionality is muted; too low and the P2
  labels detach from their mark. Starting at 0.25 and eyeballing the rendered output against real data.
- **Fast-forwarding `feature/graduate-merge-tree-hub` rewrites what PR #104 shows.** It is a strict
  fast-forward (no history rewrite), but the PR's diff and review surface grow by 4 commits. Acceptable
  because PR #104 is still a draft and has no review comments.
- **`merge-tree/` has zero test coverage.** The smoke test asserts the renderer runs and emits bytes, not that
  the meter is visually correct. C1's verification is a source grep plus a human look at the rendered file —
  weaker than a real assertion, and honest about it.
