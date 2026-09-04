# Infoviz Learning Program

Foundational information/data-visualization study. Ratified 2026-07-28: general capability; curriculum +
ELI10 briefs + evidence-traced design playbook; empirical artifact testing; hybrid cadence.
Phase 0 deliverable: the Question Inventory (docs/research/2026-07-28-territory-map/).

## Status (recorded 2026-08-21)

Phases 0-2 complete; dormant since 2026-08-11 with no Phase 3 filed. Done: Phase 0 (territory map, 36 source
cards, 7-track curriculum), Phase 1 (perception & encoding, P1-P7, 2026-07-30), Phase 2 (dashboards &
operational UI, D1-D8, assimilated 2026-08-11 via PR #112). The playbook carries 15 evidence-graded rules
(P1-P7 and D1-D8). It said 16 until 2026-09-04: a grep for lines opening `**P<n>` returns 16 because
`**P1 holds.**` in P1's own evidence paragraph matches the same shape as a rule statement. Counted by
DISTINCT RULE ID, which is what a reader of the playbook counts, it is 15.
By the curriculum's own terms the load-bearing pair (Tracks 1+2) is finished.

## Resume order (when the program picks back up)

1. **Phase 3 = Track 6 (network/hierarchy/graph viz).** The curriculum's own trigger has fired: Track 6 is
   marked "read first if a DAG project is live," and the chain-map grid renderer (comms-delivery-surfaces S2,
   filed 2026-08-20) is a live DAG project whose rendering grammar was chosen from taste and one approved mock,
   not from Track 6's evidence (node-link vs. matrix, edge bundling, hairball literature). Time it BEFORE S2
   productization so the reading de-risks code about to be written.
2. **Track 4 (narrative & explanatory).** Includes the Schwabish annotation piece — the curriculum names it as
   the top remaining ELI10 payoff after Tracks 1+2.
3. **Track 5 (interaction & exploration).** Pairs with the open P6 items (animate level transitions; arXiv
   full-text verification for the 2025-2026 semantic-zoom corroboration).
4. **Track 7 (the field itself).** Anytime filler, per the curriculum.

Carried open items, independent of track order: run both comprehension checks against a real human (still
not done for P1/P2's own checks — every empirical-test verdict in this program remains a reasoned prediction,
with the one exception below); Few beyond Ch. 1 needs a legitimate copy; the useful-chrome-vs-cute-gauge
boundary test exists in neither phase (parked, downgraded 2026-08-10).

## First real human verdict in the program (2026-09-04)

The graph-v3 kill-test's two rendered altitudes were shown to Noah and judged. **This is the only empirical
result in this program that came from a person looking rather than from a reasoned prediction**, so it is
recorded here rather than only in the artifact it judged
(`docs/research/2026-07-28-dependency-graph-tool/recommendation.md`, which is superseded).

Verdict, verbatim in substance: the SVGs were hard to read and needed two browser zoom steps; neither altitude
presented the information needed; the edges were confusing because the lines were hard to follow.

Two things generalize beyond the artifact:

- **A dead proxy.** "Zoom span" — the ratio between fitting the canvas in a 3200x1800 viewport and leaf labels
  rendering at 12px — measured **2.64x against a ≤16x bar**, a six-fold margin, and the reader still zoomed
  twice. That metric does not predict legibility at fit. Do not reuse it as though it does; it passed while
  the thing it stands in for failed.
- **A family failure, not a layout failure, at a measured scale.** The graph was 174 nodes (127 leaves, 38
  workstreams, 9 projects) with 81 edges. Ghoniem, Fekete & Castagliola put the node-link/matrix crossover at
  ~20 vertices, so this was ~9x past it, and "the lines were hard to follow" is precisely the hairball Kosara
  names. **Track 6's question — "which representation family fits this graph's size, density, and task?" — is
  therefore answered empirically at BOTH scales this estate has:** node-link fails at 174 nodes, and is
  uncontested at the 3 rows `borg link`'s `▸ CHAINS` actually renders. Reading Track 6 to de-risk a live DAG
  project is no longer the trigger it was; it becomes live again if one manifest passes ~20 rows.

A one-file review brief of Phases 1-2 (tl;dr, must-see rules, independent-review list) is generated at
`~/.local/state/borg/infoviz/phase-1-2-brief.html` (2026-08-21).
