# Source: Burch, Huang, Wakefield, Purchase, Weiskopf & Hua — State of the Art in Empirical User Evaluation of Graph Visualizations (2021)

**Full citation:** Burch, Michael, Weidong Huang, Mathew Wakefield, Helen C. Purchase, Daniel
Weiskopf, and Jie Hua. "The State of the Art in Empirical User Evaluation of Graph
Visualizations." *IEEE Access*, Vol. 9 (2021), pp. 4173–4198.
DOI: 10.1109/ACCESS.2020.3047616.
**URL:** https://eprints.gla.ac.uk/227646/1/227646.pdf
**Date accessed:** 2026-07-28
**Evidence level:** 1 (Systematic Review — a structured survey of the empirical user-study
literature on graph visualization, classifying findings across graph interpretation, memory,
and creation)
**Research topic area:** Network, hierarchy & graph visualization — graph-drawing aesthetics
literature, edge bundling, mental-map preservation, hairball alternatives (matrices)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 9/10 | Six authors spanning University of Glasgow, University of Stuttgart (VISUS), and others; Helen C. Purchase is the field's most-cited author on empirical graph-aesthetics evaluation, giving this survey direct lineage to the foundational human-factors work it synthesizes. |
| 2 | Evidence Quality | 9/10 | A systematic literature survey (Level 1) that aggregates dozens of controlled studies rather than presenting new primary data; explicitly structured taxonomy (graph interpretation / memorability / creation) rather than an ad hoc reading list. |
| 3 | Currency | 9/10 | Published December 2020 / IEEE Access Jan 2021 issue — the most recent systematic survey in this keeper set, covering studies through ~2019–2020. |
| 4 | Intent | 9/10 | Peer-reviewed academic survey in an open-access IEEE journal; explicitly aims to identify "white spots" (gaps) for future research, not to sell a technique or tool. |
| 5 | Bias & Objectivity | 8/10 | Reports contradictory findings across different replications even-handedly (e.g., edge-bundling helping some tasks and hurting others; node-link vs. matrix reversing rank depending on task) rather than picking a winner. |
| 6 | Logic & Coherence | 8/10 | Organizes evidence into a clear task taxonomy and consistently reports sample sizes and effect directions per study, letting a reader trace each claim to its source study. |
| 7 | Corroboration | 9/10 | By construction this is a corroboration engine — it cross-references Ghoniem et al., Okoe & Jianu, Okoe et al., Keller et al., Henry & Fekete's MatLink, Telea et al., and McGee & Dingliana on the same matrix-vs-node-link and edge-bundling questions. |
| 8 | Intellectual Honesty | 9/10 | Explicitly reports "no significant effect on error rates" and contradictory replication outcomes rather than smoothing them into a single tidy recommendation; ends by naming open "white spots." |
| 9 | Specificity | 8/10 | Names exact participant counts, task types, and effect directions per cited study (e.g., "835 people," "no significant difference"). |
| 10 | Relevance | 10/10 | Directly covers graph-drawing aesthetics, edge bundling, mental-map/memorability, and node-link-vs-matrix debates — four of the six areas named in the research brief, in one document. |

**Score band:** keep

## Bias Guard Check

- [x] Neutral / no strong reaction

## Key Findings

- Synthesizing multiple replications, the node-link-vs-matrix question is NOT settled the way
  Ghoniem et al. (2004) alone suggests: Okoe & Jianu's crowdsourced partial replication (112
  participants) confirmed the matrix advantage for neighborhood search, but a larger follow-up
  by Okoe et al. (835 participants) found "node-link graphs generally outperformed matrix
  representations on path-related tasks, but matrices were best on common neighbor and group
  tasks" — a genuine, unresolved task-dependent split.
- Hierarchical edge bundling (Holten's technique) has mixed empirical support: Telea et al.'s
  qualitative study found users preferred bundling for large compound graphs (less clutter),
  but McGee & Dingliana's controlled study found bundling "had a negative influence on the
  performance of path reading tasks for completion times and error rates," while speeding up
  higher-level cluster-connectivity judgments with no significant change in error rate.
- Hybrid representations (e.g., Henry & Fekete's MatLink, overlaying adjacency matrices with
  curved node-link edges) outperformed either pure representation on most tasks in a 36-person
  study — suggesting the node-link-vs-matrix framing itself may be a false binary for some
  task classes.
- The survey explicitly separates "graph interpretation," "graph memorability" (i.e.,
  mental-map-adjacent recall questions), and "graph creation" as three distinct empirical
  literatures that are too often conflated in less rigorous treatments.
- The authors close by naming unresolved "white spots" in the field — an explicit
  acknowledgment that this subfield has real open questions, not a settled canon.

## Verified Quote(s)

**Location reference:** Abstract (p. 4173, IEEE Access, as hosted in the University of
Glasgow institutional repository PDF).

> "In this article, we classify the present literature on the topmost level into graph
> interpretation, graph memorability, and graph creation where the users with their tasks
> stand in focus of the evaluation, not the computational aspects. As another outcome of this
> work, we identify the white spots in this field and sketch ideas for future research
> directions."

**Location reference:** Section on edge-bundling evaluation studies (page containing Figure 7,
"A study of node-link diagrams with and without edge bundling").

> "McGee and Dingliana [119] evaluated the user performance of 21 participants when using edge
> bundling by also varying graph density and graph size. [...] Edge bundling was found to have
> a negative influence on the performance of path reading tasks for completion times and error
> rates. Higher-level cluster connectivity tasks, instead, could be solved significantly
> faster with edge bundling, but there was no significant effect on error rates."

**Access status:** live (PDF downloaded from the University of Glasgow Enlighten repository
and converted to text with `pdftotext`; the IEEE Xplore version of record is paywalled — see
Paywalled must-reads)

## Inclusion Decision

**Decision:** Core
**Rationale:** This single open-access 2021 survey supplies the empirical cross-check for
three other keepers (Ghoniem, Holten) and covers mental-map/memorability literature that no
other keeper addresses directly. It is the strongest, most current, and most corroborated
source in the set.

**Redundancy check:** Not redundant — it is the meta-layer that contextualizes and complicates
the primary-study keepers rather than repeating them.

**Perspective category:** Academic
