# Source: Shneiderman — Tree Visualization with Tree-Maps (1992)

**Full citation:** Shneiderman, Ben. "Tree Visualization with Tree-Maps: A 2-d Space-Filling
Approach." *ACM Transactions on Graphics*, Vol. 11, No. 1 (January 1992), pp. 92–99.
**URL:** https://www.cs.umd.edu/~ben/papers/Shneiderman1992Tree.pdf
**Date accessed:** 2026-07-28
**Evidence level:** 7 (Expert Opinion / Thought Leadership — a technique-introduction paper,
not a controlled empirical evaluation; the 1992 paper itself reports no user study)
**Research topic area:** Network, hierarchy & graph visualization — compound/nested layouts,
treemaps

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 10/10 | Ben Shneiderman is a founding figure of information visualization and HCI (University of Maryland HCIL); this is the original, most-cited treemap paper. |
| 2 | Evidence Quality | 5/10 | No formal user study in the original paper — it is an algorithm/technique description with worked examples (disk-usage trees), not an evaluated experiment. |
| 3 | Currency | 4/10 (+2 timeless bonus = 6/10) | Published 1992, predates modern rendering/interaction tooling, but the core space-filling algorithm and rectangle-subdivision principle are still the basis of every treemap library in use today. |
| 4 | Intent | 9/10 | Pure academic/HCI research motivated by a real practical problem (visualizing a full 80MB shared disk among 14 lab users), published in ACM TOG. |
| 5 | Bias & Objectivity | 6/10 | Presents the technique enthusiastically as a solution without extensive discussion of when node-link trees remain preferable; later literature (see NN/g card) fills that gap. |
| 6 | Logic & Coherence | 8/10 | The algorithm (recursive slice-and-dice subdivision) is described precisely and its properties (area-proportionality, space-filling, 100% screen use) follow directly from the construction. |
| 7 | Corroboration | 9/10 | Treemaps have been reproduced, extended (ordered/squarified/quantum treemaps), and shipped in dozens of commercial and open-source visualization libraries; a 2020 IV symposium survey of treemap user studies exists specifically because the technique became a canonical research object. |
| 8 | Intellectual Honesty | 5/10 | Acknowledges treemaps are a niche complement to node-link trees for specific tasks (space attribution) but does not flag comparison/precision weaknesses that later empirical work (NN/g, treemap user-study surveys) surfaces. |
| 9 | Specificity | 8/10 | Gives a concrete algorithm, a concrete motivating dataset (UMD HCIL's shared hard disk), and reproducible construction rules. |
| 10 | Relevance | 10/10 | This is the origin paper for the treemap technique explicitly named in the research brief. |

**Score band:** keep

## Bias Guard Check

- [x] Neutral / no strong reaction

## Key Findings

- Treemaps convert an arbitrary tree into a fully space-filling 2-D rectangular map via
  recursive alternating horizontal/vertical subdivision, so every pixel of screen is used
  (unlike node-link trees, which waste space on whitespace and lines).
- Rectangle area is used to encode a node attribute (e.g., file size), letting a viewer see
  relative magnitude across an entire hierarchy in one glance without traversing the tree.
- The motivating use case was intensely practical and "boots-on-the-ground" even though the
  output is an academic paper: a shared, chronically full 80MB hard disk at UMD's HCIL lab.
- Treemaps trade off traditional tree readability (parent/child edges, path tracing) for
  compactness and magnitude-at-a-glance — a trade-off later empirical work (see NN/g card)
  shows has real costs for precise comparison tasks.

## Verified Quote(s)

**Location reference:** Introduction, opening paragraphs (PDF pp. 1–2 as served at the URL
above; OCR of the source PDF is imperfect but the sentence is intact).

> "The traditional approach to representing tree structures is as a rooted, directed graph
> with the root node at the top of the page and children nodes below the parent node with
> lines connecting them."

> "Tree-maps are a representation designed for human visualization [...] of complex
> traditional tree structures: arbitrary trees are shown with a 2-d space-filling
> representation."

**Location reference (motivation account):** University of Maryland HCIL, "A History of
Treemap Research at the University of Maryland," https://www.cs.umd.edu/hcil/treemap-history/,
opening paragraph (same institutional host, cs.umd.edu, as the paper URL above; this is the
author's own retrospective account of the 1992 paper's genesis, fetched live 2026-07-28).

> "During 1990, in response to the common problem of a filled hard disk, I became obsessed
> with the idea of producing a compact visualization of directory tree structures."

**Access status:** live (PDF fetched and converted to text with `pdftotext`; retrospective
history page fetched live via WebFetch)

## Inclusion Decision

**Decision:** Core
**Rationale:** Origin paper for treemaps, one of the six technique families explicitly named
in the research brief; Authority and Relevance are maximal; the Evidence Quality gap
(no controlled study in the original paper) is exactly why it is paired with the NN/g
practitioner-critique card and the Burch et al. 2021 survey card, both of which supply the
empirical/critical counterweight this 1992 paper lacks.

**Redundancy check:** No other keeper covers space-filling/area-encoding hierarchy layouts;
non-redundant.

**Perspective category:** Academic
