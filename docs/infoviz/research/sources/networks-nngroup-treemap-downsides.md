# Source: Laubheimer / Nielsen Norman Group — Treemaps for Space-Constrained Visualization of Hierarchies (2019)

**Full citation:** Laubheimer, Page. "Treemaps: Data Visualization of Complex Hierarchies."
Nielsen Norman Group, September 29, 2019.
**URL:** https://www.nngroup.com/articles/treemaps/
**Date accessed:** 2026-07-28
**Evidence level:** 7 (Expert Opinion / Thought Leadership — an institutional UX-research
practitioner article synthesizing perceptual-psychology principles, not a novel controlled
study)
**Research topic area:** Network, hierarchy & graph visualization — compound/nested layouts,
treemaps

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 7/10 | Nielsen Norman Group is a well-established, widely-cited UX research and consulting institution; the article does not disclose the author's specific academic credentials, but NN/g's editorial process and reputation function as an institutional quality gate. |
| 2 | Evidence Quality | 5/10 | Synthesizes established perceptual-psychology findings (area is not a preattentive visual attribute, unlike position or length) rather than presenting a new study; no original sample or methodology of its own. |
| 3 | Currency | 8/10 | Published 2019, within the "≤5 years, data may be older" band, and the underlying perceptual-psychology claims it cites are foundational/timeless (preattentive-attribute research). |
| 4 | Intent | 6/10 | NN/g articles serve both education and lead-generation for the firm's UX training/consulting business; this piece reads as genuine practitioner education rather than product marketing. |
| 5 | Bias & Objectivity | 7/10 | Balances treemap strengths (space efficiency, magnitude-at-a-glance for large hierarchies) against explicit, named downsides (poor precise-comparison support, label overcrowding) rather than one-sidedly promoting or dismissing the technique. |
| 6 | Logic & Coherence | 8/10 | Ties the "poor for precise comparison" claim to an established perceptual mechanism (area is not preattentively processed the way length or position are) rather than asserting it as opinion. |
| 7 | Corroboration | 6/10 | The area-perception limitation is well-established in the broader visualization-perception literature (Cleveland & McGill-style hierarchies of encoding effectiveness), though this article does not itself cite that literature by name. |
| 8 | Intellectual Honesty | 7/10 | Explicitly frames treemaps as good for some tasks (relative-size overview) and bad for others (precise comparison, small-category legibility), rather than a blanket endorsement or rejection. |
| 9 | Specificity | 7/10 | Gives concrete, named failure modes (labels too small to read, "sea of tiny rectangles") rather than vague caution. |
| 10 | Relevance | 9/10 | Directly addresses treemap usability limitations, the practitioner-facing counterweight to the Shneiderman origin paper, and is itself a plain-language, non-specialist-oriented source relevant to RQ4 (ELI10 bar). |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Treemaps are well suited to showing relative magnitude across a large hierarchy at a glance
  (e.g., sales-by-category data) because they use 100% of screen space and area scales with
  the encoded attribute.
- Area is explicitly named as a weak visual-encoding channel: unlike position or length, area
  is "not one of these preattentive attributes," which is why treemaps are poorly suited to
  tasks requiring precise comparison between two similarly-sized categories.
- At high category counts, treemaps degrade into "a sea of tiny rectangles, many too small to
  bear a text label" — an institutional practitioner naming the same scaling failure mode that
  the hairball critique (Kosara card) names for node-link diagrams, but for area-based
  hierarchy layouts instead.
- The article is itself written in plain, non-specialist language aimed at working UX
  practitioners, making it a useful model for RQ4 (ELI10-passing communication of a technical
  visualization trade-off).

## Verified Quote(s)

**Location reference:** "Treemaps' Downsides" section.

> "Area is not one of these preattentive attributes...they are not suited for tasks involving
> precise comparisons."

**Location reference:** "Visually Overwhelming" subsection.

> "The treemap becomes a sea of tiny rectangles, many too small to bear a text label."

**Access status:** live (fetched directly from nngroup.com)

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Included specifically to diversify perspective category (Institutional) and to
supply the practitioner-facing critique that the Shneiderman 1992 origin paper does not itself
provide, directly matching RQ4's ELI10 relevance criterion.

**Redundancy check:** Adds a named, plain-language failure mode (area is not preattentive;
label overcrowding) not present in the Shneiderman card; not redundant.

**Perspective category:** Institutional
