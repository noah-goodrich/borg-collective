# Source: Ghoniem, Fekete & Castagliola — Readability of Node-Link vs. Matrix Representations (2004/2005)

**Full citation:** Ghoniem, Mohammad, Jean-Daniel Fekete, and Philippe Castagliola. "A
Comparison of the Readability of Graphs Using Node-Link and Matrix-Based Representations."
Proc. IEEE Symposium on Information Visualization (InfoVis'04), Austin, TX, Oct. 2004,
pp. 17–24. Extended as "On the Readability of Graphs Using Node-Link and Matrix-Based
Representations: A Controlled Experiment and Statistical Analysis," *Information
Visualization* 4, no. 2 (2005): 114–135.
**URL:** http://www-sop.inria.fr/orion/COGC/teams/INSITUghoniem-fivj05-final.pdf
**Date accessed:** 2026-07-28
**Evidence level:** 2 (Randomized/Controlled Experiment — 36 participants, seven generic graph
tasks, statistical analysis with regression on size/density)
**Research topic area:** Network, hierarchy & graph visualization — hairball critiques and
alternatives (matrices)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 9/10 | Jean-Daniel Fekete (INRIA/AVIZ) is a leading InfoVis researcher; published at InfoVis'04, the top venue, and later in a peer-reviewed journal. |
| 2 | Evidence Quality | 9/10 | A genuine controlled experiment (36 participants, 9 random graphs, 7 tasks, multiple-regression analysis of size/density interaction) — one of the few Level-2 studies in this subfield. |
| 3 | Currency | 5/10 | 2004/2005 publication; the core finding has since been partially replicated and partially complicated by later crowdsourced replications (Okoe & Jianu; Okoe et al.), per the Burch et al. 2021 survey — the world of graph tooling has changed but the underlying human-perception finding has held up reasonably well. |
| 4 | Intent | 9/10 | Pure academic HCI/visualization research; no commercial motive. |
| 5 | Bias & Objectivity | 7/10 | Explicitly reports the one task (path-finding) where node-link diagrams win, rather than only reporting results favorable to the matrix representation it ultimately recommends. |
| 6 | Logic & Coherence | 8/10 | Conclusions are tied directly to task-by-task quantitative results (e.g., 57% vs. 25% correct-answer rates on large graphs) rather than asserted generally. |
| 7 | Corroboration | 7/10 | Partially corroborated: Okoe & Jianu's crowdsourced partial replication (112 participants) confirmed the matrix advantage for neighborhood search; a follow-up by Okoe et al. (835 participants) found node-link diagrams *generally* outperformed matrices on path tasks but matrices won on common-neighbor/group tasks — real nuance, not a clean confirmation (see Burch et al. 2021 survey card). |
| 8 | Intellectual Honesty | 8/10 | Explicitly flags that all participants were already familiar with node-link diagrams and had no prior matrix exposure, meaning the matrix's disadvantage from unfamiliarity was likely understated, not overstated, in its favor — an unusual, self-critical caveat. |
| 9 | Specificity | 9/10 | Reports precise percentages (e.g., "57% of correct answers on large graphs" for matrices vs. "25%" for node-link) and names the exact seven tasks tested. |
| 10 | Relevance | 10/10 | Directly addresses the brief's "hairball critiques and alternatives (matrices...)" topic with the field's most-cited head-to-head empirical comparison. |

**Score band:** keep

## Bias Guard Check

- [x] Neutral / no strong reaction

## Key Findings

- For graphs larger than ~20 vertices, matrix-based visualizations outperformed node-link
  diagrams on most of seven generic graph-reading tasks (find node, find link, find common
  neighbor, most-connected node, link count, etc.).
- Path-finding was the one task consistently better on node-link diagrams throughout the
  evaluation — a nuance the authors flag rather than smooth over.
- For small, sparse graphs, node-link diagrams remained more readable and more familiar than
  matrices; the crossover point is graph size/density, not a blanket superiority claim.
- The authors attribute node-link degradation to visual clutter from overlapping links, which
  eventually causes users to guess rather than genuinely read the diagram (evidenced by rising
  error rates, not just longer completion times).
- Later replications (documented in the Burch et al. 2021 survey, see companion card)
  complicate the picture: with larger, crowdsourced samples, node-link diagrams recovered an
  edge on path-related tasks specifically, while matrices remained better for neighbor/group
  tasks — this is one of the subfield's live empirical debates, not settled consensus.

## Verified Quote(s)

**Location reference:** Abstract (p. 1 of the INRIA-hosted final PDF).

> "In this article, we describe a taxonomy of generic graph related tasks along with a
> computer-based evaluation designed to assess the readability of two representations of
> graphs: matrix-based representations and node-link diagrams. This evaluation encompasses
> seven generic tasks and leads to insightful recommendations for the representation of
> graphs according to their size and density. Typically, we show that when graphs are bigger
> than twenty vertices, the matrix-based visualization outperforms node-link diagrams on most
> tasks. Only path finding is consistently in favor of node-link diagrams throughout the
> evaluation."

**Location reference:** Conclusion section (near end of document, INRIA-hosted final PDF).

> "These techniques proved to be complementary: node-link diagrams are well suited for small
> graphs, and matrices are suitable for large or dense graphs. Path related tasks remain
> difficult on both representations and require an appropriate interaction that helps perform
> them."

**Access status:** live (PDF downloaded and converted to text with `pdftotext`; the
ACM/Sage-hosted versions of this paper returned 403 errors, but the INRIA author-hosted final
PDF at the URL above was fully retrievable and machine-readable)

## Inclusion Decision

**Decision:** Core
**Rationale:** This is the field's landmark controlled experiment on the "hairball" problem's
main proposed cure (matrices) and directly matches the brief's language ("hairball critiques
and alternatives (matrices, small multiples)"). It is also the strongest Level-2 evidence
source in the whole keeper set — the weakest-scoring dimension (Currency, 5/10, since later
replications complicate the simple story) is the reason to read it alongside the Burch et al.
2021 survey rather than in isolation.

**Redundancy check:** Adds the original controlled-experiment data and exact task-level
statistics that the Burch et al. 2021 survey card only summarizes secondhand; not redundant.

**Perspective category:** Academic
