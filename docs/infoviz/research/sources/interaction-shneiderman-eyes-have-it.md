# Source: Shneiderman (1996) — "The Eyes Have It" (the original mantra paper)

**Full citation:** Shneiderman, B. "The Eyes Have It: A Task by Data Type Taxonomy for Information
Visualizations." Proceedings of the 1996 IEEE Symposium on Visual Languages, Boulder, CO, 3-6
September 1996, pp. 336-343. DOI: 10.1109/VL.1996.545307.
**URL:** https://ieeexplore.ieee.org/document/545307
**Date accessed:** 2026-07-28
**Evidence level:** Level 7 (Expert Opinion / Thought Leadership) — Shneiderman himself frames the
paper as descriptive/explanatory synthesis of his design experience, not an empirical study.
**Research topic area:** Interaction & exploration — this is the founding text of the "overview
first, zoom and filter, details-on-demand" mantra plus the seven-task taxonomy (overview, zoom,
filter, details-on-demand, relate, history, extract) that every later focus+context / semantic-zoom
/ progressive-disclosure paper cites as ancestor.

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 10/10 | Ben Shneiderman is the founding figure of the HCI/InfoVis field (University of Maryland, ACM/IEEE fellow); this is his single most-cited paper (5,700+ citations). |
| 2 | Evidence Quality | 4/10 | No empirical study — it is a design-experience synthesis and taxonomy proposal. Craft & Cairns (a keeper below) confirm no validation study exists for the mantra itself. |
| 3 | Currency | 5/10 | Published 1996 (pre-2020, well outside the 5-10-year band); +2 timeless bonus applied because the mantra and taxonomy remain the field's default reference vocabulary 30 years on, giving an adjusted 5/10 rather than 1-2/10. |
| 4 | Intent | 9/10 | Academic conference paper, pure knowledge contribution, no commercial angle. |
| 5 | Bias & Objectivity | 6/10 | Presents the mantra as a general prescription without discussing when it fails; does not survey competing frameworks. Scored down slightly (bias-guard: I am inclined to treat this as canon, so held to a harder standard here). |
| 6 | Logic & Coherence | 7/10 | The taxonomy is internally consistent and the mantra follows plausibly from the seven tasks, but the leap from "these are useful tasks" to "this is the correct sequence for all systems" is asserted, not derived. |
| 7 | Corroboration | 9/10 | Corroborated as the origin point by every other source in this corpus (Craft & Cairns, Cockburn et al., infovis-wiki, NNG) — near-universal citation. |
| 8 | Intellectual Honesty | 6/10 | Shneiderman later described the paper's claims as "descriptive and explanatory" rather than prescriptive (per Card & Mackinlay, quoted in Craft & Cairns) — a hedge — but the paper itself does not flag its own lack of empirical backing. |
| 9 | Specificity | 8/10 | Concrete, operational taxonomy (seven named tasks × seven data types) rather than vague principles. |
| 10 | Relevance | 10/10 | This is the primary object of study for the "interaction & exploration" subfield; every other keeper in this card set responds to it. |

**Score band:** keep — This is the foundational primary text; every downstream debate in this
subfield references it directly. Weighted average lands roughly in the high-6s to low-7s once the
timeless-currency bonus is applied, clearing the keep bar on authority and relevance alone even
though evidence quality is weak (which is itself the finding: the mantra is influential opinion, not
validated science — see the Craft & Cairns card for the falsification angle).

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings

- Proposes the "Visual Information-Seeking Mantra": "Overview first, zoom and filter, then
  details-on-demand" as the organizing principle for interactive visualization design.
- Introduces a task-by-data-type taxonomy: seven data types (1D, 2D, 3D, temporal,
  multidimensional, tree, network) crossed with seven generic user tasks (overview, zoom, filter,
  details-on-demand, relate, history, extract).
- The mantra is explicitly a synthesis of Shneiderman's own design experience, not a report of an
  experiment — later scholarship (Craft & Cairns 2005) confirms no rigorous validation study of the
  mantra as a whole exists even decades later.
- The paper spawned an entire lineage of interaction techniques built explicitly to satisfy the
  mantra's three phases: overview+detail, zooming, focus+context, and cue-based / brushing-linking
  systems (per Cockburn, Karlson & Bederson 2008).

## Verified Quote(s)

**Location reference:** IEEE Xplore abstract/metadata page for document 545307; mantra phrase as
reproduced and directly attributed to this paper on the InfoVis:Wiki mirror page
(https://infovis-wiki.net/wiki/Visual_Information-Seeking_Mantra), corroborated independently by
Craft & Cairns (2005), p.1, paragraph under "1. Introduction."

> "Overview first, zoom and filter, then details-on-demand."

> The Mantra, "Overview first, zoom and filter, then details-ondemand", describes how data should
> be presented on screen so that it is most effective for users.

**Access status:** cached/partial — IEEE Xplore's document page returned no fetchable body text
(subscription/paywall gate; WebFetch returned empty content). The mantra sentence itself is quoted
character-for-character and independently corroborated by two secondary academic sources (Craft &
Cairns 2005, cross-verified against infovis-wiki.net), so the quote is confidently attributed to
Shneiderman 1996 even though the full original PDF could not be fetched live. Treat this card's
attribution as verified-by-corroboration rather than verified-live.

## Inclusion Decision

**Decision:** Core
**Rationale:** Authority (10/10) and Relevance (10/10) are maximal — this is the object every other
source in the subfield reacts to, agrees with, or falsifies. Cannot map the subfield's canon
without it, despite weak native evidence quality.

**Redundancy check:** Not redundant — no other source in this set states the original mantra in
its own words; all others are commentary on or extensions of it.

**Perspective category:** Academic
