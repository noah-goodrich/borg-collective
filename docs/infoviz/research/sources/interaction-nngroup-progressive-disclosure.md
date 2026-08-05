# Source: Nielsen (2006, NN/G) — "Progressive Disclosure"

**Full citation:** Nielsen, J. "Progressive Disclosure." Nielsen Norman Group, December 3, 2006.
**URL:** https://www.nngroup.com/articles/progressive-disclosure/
**Date accessed:** 2026-07-28
**Evidence level:** Level 4 (Expert Consensus / Professional Body Guidance) — NN/G is a
practice-standard usability consultancy whose guidance is treated as expert-consensus reference
material across the UX industry, though this specific article does not present original controlled
data.
**Research topic area:** Interaction & exploration — progressive disclosure is one of the four named
interaction mechanisms in the subfield brief, and is the direct interaction-design analogue to
Shneiderman's "details-on-demand" step of the mantra.

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 8/10 | Jakob Nielsen co-founded NN/G, has a PhD in HCI, and is one of the most widely credentialed usability authorities in the industry; NN/G's guidance is a de facto professional standard cited across UX practice. |
| 2 | Evidence Quality | 5/10 | The article states design guidance drawn from NN/G's own usability-testing practice but does not cite a specific study, sample size, or methodology in the accessible text — closer to expert consensus/practitioner distillation than reported primary research. |
| 3 | Currency | 3/10 | Published December 3, 2006 — pre-2020, outside even the 5-10 year band; no timeless bonus fully applied because interface conventions (disclosure levels, navigation cues) have evolved with mobile/touch UI since 2006, though the core two-level heuristic is still commonly repeated in 2020s UX writing (per this search round's 2025-26 secondary articles restating the same guidance). Partial credit given for continued citation. |
| 4 | Intent | 7/10 | NN/G sells training/consulting, so there is a commercial dimension, but this specific article reads as general-audience education rather than a lead-gen pitch (per the rubric's 7-8 anchor: "professional development... open documentation"). |
| 5 | Bias & Objectivity | 6/10 | Presents progressive disclosure favorably overall but does include an explicit misuse warning (disclosure levels beyond 2 "typically have low usability") — a real acknowledgment of failure modes, though the piece does not deeply engage alternative schools of thought (e.g., "just show everything" critics). |
| 6 | Logic & Coherence | 7/10 | The core heuristic (defer secondary/rare options, keep primary ones visible) follows a clear, testable logic, and the stated boundary condition (2-level cap) is a specific, falsifiable claim rather than a vague platitude. |
| 7 | Corroboration | 6/10 | The same 2-level-cap heuristic and "hide secondary, not primary" framing recurs across multiple independent 2025-26 UX-industry articles found in this search round (Lollypop Design, UXPin, Interaction Design Foundation glossary) — moderate independent corroboration, though most secondary sources may themselves be citing NN/G rather than independently verifying it. |
| 8 | Intellectual Honesty | 7/10 | Explicitly flags the failure mode of over-application ("designs that go beyond 2 disclosure levels typically have low usability because users often get lost") rather than presenting the technique as risk-free. |
| 9 | Specificity | 7/10 | Gives a concrete, actionable rule (max ~2 disclosure levels) and named consequence (users get lost) rather than only abstract principle. |
| 10 | Relevance | 9/10 | Progressive disclosure is named explicitly in the subfield brief as one of the four core interaction mechanisms to map. |

**Score band:** keep — Authority and Relevance are strong; the main drag is Currency (2006) and thin
Evidence Quality (no cited methodology in the accessible article). This is the corpus's named
weakest keep: it clears the bar mainly on authority/relevance/intellectual-honesty rather than
methodological rigor, and is included as a gap-fill because no more rigorous, recent, freely
accessible primary source specifically on progressive-disclosure-as-a-named-pattern surfaced in
this search round.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Progressive disclosure's core mechanism: "Initially, show users only a few of the most important
  options. Offer a larger set of specialized options upon request" — this is a direct interface
  analogue to the "details-on-demand" stage of Shneiderman's mantra.
- The technique has a hard practical ceiling: designs with more than two disclosure levels
  "typically have low usability because users often get lost" — an explicit, falsifiable limit on
  how far the pattern should be pushed.
- Feature placement matters more than hiding per se: "You must disclose everything that users
  frequently need up front, so that they have to progress to the secondary display only on rare
  occasions" — misclassifying a frequently-needed feature as "secondary" is the primary failure
  mode, not the act of disclosure staging itself.
- This directly supports RQ4 (relevance to ELI10 operational-info readability): progressive
  disclosure is presented as a way to keep an initial view legible while still making full detail
  reachable — but the 2-level ceiling is a concrete constraint any operational dashboard/report
  design should respect.

## Verified Quote(s)

**Location reference:** Nielsen Norman Group article "Progressive Disclosure," definition
paragraph near top of article, and the paragraph addressing disclosure-level limits (mid-article,
under the discussion of how many levels to use).

> Initially, show users only a few of the most important options. Offer a larger set of specialized
> options upon request.

> In practice, designs that go beyond 2 disclosure levels typically have low usability because users
> often get lost.

> You must disclose everything that users frequently need up front, so that they have to progress to
> the secondary display only on rare occasions.

**Access status:** live — fetched directly from the nngroup.com article URL; quotes returned
verbatim by the fetch and attributed to this exact host.

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Named as the weakest keep in this run per the rubric's real-cut rule — it survives on
authority/relevance/honesty but is the most dated (2006) and least methodologically rigorous
(Evidence Quality 5/10, no cited study) of the five keepers. Included because progressive disclosure
is explicitly named in the subfield brief and no stronger, more current, freely accessible primary
source specifically addressing it as a named pattern was found in four search passes.

**Redundancy check:** Not redundant — the only card addressing progressive disclosure specifically
as a named, actionable UX pattern with a concrete failure-mode boundary (2-level cap).

**Perspective category:** Institutional
