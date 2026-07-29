# Source: Holten — Hierarchical Edge Bundles (2006)

**Full citation:** Holten, Danny. "Hierarchical Edge Bundles: Visualization of Adjacency
Relations in Hierarchical Data." *IEEE Transactions on Visualization and Computer Graphics*,
Vol. 12, No. 5 (2006), pp. 741–748. (Proc. IEEE Visualization / InfoVis 2006.)
**URL:** https://research.tue.nl/en/publications/hierarchical-edge-bundles-visualization-of-adjacency-relations-in/
**Date accessed:** 2026-07-28
**Evidence level:** 7 (Expert Opinion / Thought Leadership — technique paper with only an
informal, qualitative user reaction, not a controlled experiment)
**Research topic area:** Network, hierarchy & graph visualization — edge bundling, compound
graphs

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 9/10 | Published in TVCG (top venue) by Danny Holten (TU Eindhoven), the paper that defined the "hierarchical edge bundling" technique now standard in visualization toolkits (D3, Gephi, etc.). |
| 2 | Evidence Quality | 4/10 | The paper is a method/algorithm contribution; it reports the technique was "evaluated informally with prospective users" rather than a controlled study with quantitative task performance. |
| 3 | Currency | 6/10 | 2006 publication; the core method is still the reference implementation cited by nearly every later edge-bundling variant, but it predates the empirical work (Telea et al.; McGee & Dingliana, see Burch et al. 2021 card) that later tested it against plain node-link diagrams. |
| 4 | Intent | 9/10 | Pure academic visualization research, peer-reviewed IEEE TVCG publication. |
| 5 | Bias & Objectivity | 5/10 | Presents bundling primarily as a clutter-reduction win; does not test or discuss path-tracing costs, which later controlled studies (see Burch et al. 2021 card) find significant. |
| 6 | Logic & Coherence | 8/10 | The construction (B-spline curves bent toward the tree path between two nodes, bundling strength as a tunable parameter) is precisely specified and its clutter-reduction property follows directly. |
| 7 | Corroboration | 8/10 | Method has been re-implemented and cited extensively (Gephi, D3.js, Cytoscape); its qualitative benefit (reduced clutter for large compound graphs) is corroborated by Telea et al.'s later user study, per the Burch et al. 2021 survey card. |
| 8 | Intellectual Honesty | 5/10 | Does not flag that the visual smoothing of edges can obscure exact connectivity or path-tracing precision — a limitation surfaced only in later independent evaluations. |
| 9 | Specificity | 8/10 | Concrete algorithm (piecewise cubic B-splines, control-point straightening, alpha blending by curve length, RGB gradient for edge direction) with reproducible figures. |
| 10 | Relevance | 10/10 | This is the namesake paper for "edge bundling (Holten)" explicitly listed in the research brief. |

**Score band:** keep

## Bias Guard Check

- [x] Neutral / no strong reaction

## Key Findings

- A "compound graph" — a data set with both a hierarchy on the items and non-hierarchical
  adjacency edges between them — is visualized by first laying out the hierarchy with a
  standard tree method, then bending each adjacency edge (as a B-spline) toward the tree path
  connecting its endpoints, "bundling" edges that share tree structure together.
- Bundling strength is a continuous, user-adjustable parameter between straight-line edges
  (no bundling) and edges that fully follow the hierarchy skeleton (full bundling).
- The technique is explicitly presented as clutter/hairball reduction: bundling reveals
  higher-level, aggregate connectivity patterns between subtrees that are invisible when every
  individual adjacency edge is drawn straight.
- The method is generic — it composes with any existing tree-layout algorithm (radial,
  icicle, etc.), which is why it propagated into general-purpose visualization toolkits
  rather than staying a one-off technique.
- The original paper's evaluation was informal (qualitative feedback from prospective users),
  not a controlled task-performance study — a gap later closed, with mixed results, by Telea
  et al. and McGee & Dingliana (see the Burch et al. 2021 survey card for the empirical
  follow-up, which found bundling speeds up cluster-connectivity judgments but can *slow down
  and reduce accuracy* on path-tracing tasks).

## Verified Quote(s)

**Location reference:** Abstract, as indexed on the TU Eindhoven Research Portal record page.

> "A compound graph is a frequently encountered type of data set. Relations are given between
> items, and a hierarchy is defined on the items as well."

**Access status:** live (abstract fetched from the TU/e institutional research portal;
the primary TVCG PDF is paywalled behind IEEE Xplore, so full-text beyond the abstract is
cached/partial — see Paywalled must-reads)

## Inclusion Decision

**Decision:** Core
**Rationale:** Explicitly named in the research brief ("edge bundling (Holten)"); Authority
and Relevance both maximal; this is the technique's origin paper and cannot be substituted.

**Redundancy check:** No other keeper covers edge bundling; non-redundant. The empirical
stress-test of this technique (does bundling actually help?) is covered by the Burch et al.
2021 survey card rather than duplicated here.

**Perspective category:** Academic
