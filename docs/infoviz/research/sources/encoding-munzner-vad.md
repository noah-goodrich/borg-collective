# Source: Munzner, "Visualization Analysis and Design" (What-Why-How framework)

**Full citation:** Munzner, Tamara. *Visualization Analysis and Design*. CRC Press / A K Peters
Visualization Series, 2014. Reviewed in: Romanowski, Thabata. "Visualisation Analysis & Design by
Tamara Munzner or the What-Why-How of data viz." datarocks.co.nz, 14 Apr 2023 (updated 31 May
2024).
**URL:** https://www.datarocks.co.nz/post/data-viz-bookshelf_visualization-analysis-design-tamara-munzner
**Date accessed:** 2026-07-28
**Evidence level:** Level 7 (Expert Opinion / Thought Leadership) — a synthesized design framework
authored by a recognized vis-research professor, not itself a single experiment, though it
aggregates and cites primary perceptual studies throughout.
**Research topic area:** Visual encoding & the grammar of graphics — the what/why/how framework,
marks and channels, expressiveness/effectiveness principles.

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 9/10 | Munzner is a tenured CS professor (UBC) whose textbook is the standard graduate/professional vis-analysis reference; the card itself is a secondary review, but the underlying work's authority is unambiguous. |
| 2 | Evidence Quality | 7/10 | The framework distills decades of published perceptual and task-analysis research (Cleveland/McGill, Bertin, Mackinlay) into a taxonomy rather than presenting new primary data itself. |
| 3 | Currency | 8/10 | Published 2014, still the dominant teaching framework in 2026 with active course use; core taxonomy (marks/channels) is largely timeless perceptual science, so no penalty for the decade gap. |
| 4 | Intent | 9/10 | Written as an academic textbook/teaching tool with free companion lecture videos and slides; no commercial angle. |
| 5 | Bias & Objectivity | 7/10 | Presents the framework as a flexible guide (explicitly "not a straightjacket" per the review), acknowledging iterative, non-linear real use — I largely agree with this framework's centrality, so scored this dimension harder rather than generously. |
| 6 | Logic & Coherence | 8/10 | The nested what/why/how decomposition is internally consistent and widely reproduced in later vis pedagogy without contradiction. |
| 7 | Corroboration | 8/10 | Corroborated by Munzner's own later publications, wide adoption in university vis courses (UBC, Univ. Wien teaching slides found in search), and citation in ggplot2/Wickham-lineage literature. |
| 8 | Intellectual Honesty | 7/10 | The review notes Munzner explicitly frames the process as iterative/non-prescriptive rather than a rigid algorithm — an honest hedge about the framework's limits. |
| 9 | Specificity | 7/10 | Marks/channels taxonomy and expressiveness/effectiveness principles are concrete and named; this particular secondary-review card is less specific than the primary text would be. |
| 10 | Relevance | 10/10 | Directly the canonical "what-why-how / marks and channels" reference the research question names. |

**Score band:** keep

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings

- The What-Why-How framework splits any visualization design task into nested questions: **what**
  data is being shown (data abstraction), **why** the user needs it (task abstraction), and **how**
  it is visually encoded and interacted with (idiom design) — Munzner frames this as recursive, not
  linear (per review text: "chances are that if this instance is successful, other instances will
  be chained from it").
- Munzner explicitly warns against treating the process as a rigid sequence: it is a guide, not a
  "straightjacket."
- Marks (points, lines, areas) are the geometric primitives; channels (position, color, size,
  shape, etc.) control how marks appear — this vocabulary is the connective tissue between
  Bertin's older "retinal variables" and modern tool implementations (per companion search
  findings from Munzner's own book site).
- The expressiveness principle: the encoding should show all and only the information in the data
  (ordered data via ordered channels, unordered data must not imply false order).
- The effectiveness principle: channel salience should be matched to attribute importance (most
  noticeable channels reserved for the most important attributes).

## Verified Quote(s)

**Location reference:** datarocks.co.nz review, "What-Why-How" section, paragraphs 2–4 (as
rendered on the page; article is unpaginated).

> "One particularly great point the author makes is that the process shall not be seen as a 'straightjacket' but as a guide to get us started when doing data viz work."

> "An instance of the What-Why-How process should satisfy one or a small group of analytical inquiries, but chances are that if this instance is successful, other instances will be chained from it."

> "This is brilliantly elegant because it indeed describes the mental models we employ as visualisation designers: first, we define what data will feed into our analysis, then we figure out why we need it to be a certain way, what's to be gained from it?"

**Access status:** live (review page fetched successfully 2026-07-28; the underlying book itself
was not directly fetched — see Redundancy check below).

## Inclusion Decision

**Decision:** Core
**Rationale:** Munzner's framework is the modern lingua franca for "what/why/how" and "marks and
channels" named explicitly in the research track; high authority, high relevance, strong
corroboration in the field.

**Redundancy check:** No source in this batch duplicates the what/why/how taxonomy. Note: the
primary book itself is paywalled/not freely fetchable in full; this card is built on a
secondary review plus Munzner's own book-site index page (confirmed free slides/video exist at
https://www.cs.ubc.ca/~tmm/vadbook/) rather than the full book text — flagged honestly as a
partial-access situation for the primary source, mitigated by a credible, detailed third-party
review plus confirmation that Munzner's own teaching materials are freely available.

**Perspective category:** Academic
