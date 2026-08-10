# Source: Cleveland & McGill (1984) — "Graphical Perception: Theory, Experimentation, and Application
to the Development of Graphical Methods"

**Full citation:** Cleveland, William S., and Robert McGill. "Graphical Perception: Theory, Experimentation,
and Application to the Development of Graphical Methods." *Journal of the American Statistical Association*,
vol. 79, no. 387, September 1984, pp. 531-554.
**URL:** https://www.tandfonline.com/doi/abs/10.1080/01621459.1984.10478080 (paywalled landing page; verbatim
quote below sourced from an accessible secondary summary of the paper, see Access status)
**Date accessed:** 2026-07-28
**Evidence level:** Level 2 (Randomized/controlled perceptual experiment — within-subject psychophysics
experiments with randomized stimulus order; not an RCT on real-world behavior, but the closest analogue in
this hierarchy for controlled perception psychophysics)
**Research topic area:** Perception & graphical cognition — encoding-effectiveness ranking (the foundational
paper the entire subfield responds to, replicates, or contests)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 10/10 | Cleveland was a Bell Labs statistician who essentially founded quantitative graphical-perception research; McGill was his co-author on multiple foundational JASA papers. Published in JASA, the flagship US statistics journal. |
| 2 | Evidence Quality | 8/10 | Controlled psychophysics experiments (not a single RCT) with randomized stimulus presentation and explicit accuracy scoring (log absolute error), designed to isolate one perceptual task at a time — rigorous for its era, though sample sizes and subject pools were small by modern crowdsourcing standards. |
| 3 | Currency | 6/10 (+2 timeless bonus applied, capped at 10 per rubric = 8) | Published 1984, so the raw data is over 40 years old, but the core ranking (position > length > angle > area > volume > color) is a foundational, still-taught, still-replicated perceptual claim — this is exactly the "timeless principle" case the rubric bonus is meant for. |
| 4 | Intent | 9/10 | Pure academic inquiry aimed at improving statistical graphics methodology; no commercial angle. |
| 5 | Bias & Objectivity | 8/10 | Presents a theory and then subjects it to experimental test, including tasks where the theory's predictions could fail; reasonably balanced for a foundational paper. (Scored on the harder end per bias-guard since I broadly agree with the ranking's continued relevance.) |
| 6 | Logic & Coherence | 9/10 | The ordering is derived directly from the experimental error rates reported; the theory-to-experiment-to-application chain is explicit and has held up under scrutiny for four decades. (Scored on the harder end per bias-guard.) |
| 7 | Corroboration | 10/10 | Extremely widely corroborated — replicated by Heer & Bostock (2010) via crowdsourcing, incorporated into Munzner's *Visualization Analysis and Design* textbook, and even the papers that complicate it (e.g. "The Risks of Ranking," 2022) do so by re-running Cleveland & McGill's own experimental design rather than rejecting it outright. |
| 8 | Intellectual Honesty | 6/10 | The original paper is confident in its ranking and doesn't extensively flag individual-difference variance or task-dependence — later work (see companion contrarian card) shows this confidence was somewhat overstated. (Scored on the harder end per bias-guard.) |
| 9 | Specificity | 9/10 | Concrete, reproducible experimental tasks (10 named elementary perceptual tasks) with quantified accuracy rankings — the paper is the definition of specificity for this subfield. |
| 10 | Relevance | 10/10 | This is the origin paper for the entire "which visual channel does the eye rank well" question the track is investigating. |

**Score band:** keep

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8

## Key Findings

- Cleveland & McGill define a set of "elementary perceptual tasks" (position along a common scale, position
  along non-aligned scales, length, direction, angle, area, volume, curvature, shading, color saturation) that
  people use, singly or in combination, to decode quantitative information from any graph.
- They propose and experimentally test an ordering of these tasks by decoding accuracy, running paired
  comparisons (e.g., bar chart vs. pie chart, testing position-based judgment against angle-based judgment).
- The resulting ranking — position (common scale) > position (non-aligned scale) > length ≈ direction ≈ angle >
  area > volume ≈ curvature > shading/color saturation — became the theoretical basis for arguing that bar
  charts (position/length) reliably outperform pie charts (angle) and 3D/volume encodings for quantitative
  comparison tasks.
- The paper explicitly frames the ranking as a tool for the *development* of new graphical methods, not merely
  a post-hoc description — i.e., it argues designers should choose encodings from the top of the ranking
  whenever the data and design goals permit.

## Verified Quote(s)

**Location reference:** Secondary summary/paraphrase reproduced in a public reading-notes blog post covering
the 1984 paper's ranked list of elementary perceptual tasks (creativeartsadventure.wordpress.com, 2017-01-02
post "CLEVELAND & MCGILL — Graphical Perception..."), since the JASA/Taylor & Francis landing page returned
HTTP 403 to automated fetch and full text is paywalled.

> "1. Position along a common scale
> 2. Positions along nonaligned scales
> 3. Length, direction, angle
> 4. Area
> 5. Volume, curvature
> 6. Shading, colour saturation"

**Access status:** cached/partial — the primary JASA article is paywalled (Taylor & Francis, 403 on automated
fetch); the ranked list above is a third-party paraphrase of the paper's core finding, not a direct quote of
Cleveland & McGill's own sentences. This paper is flagged below under Paywalled must-reads because the
original experimental methodology and discussion sections (not just the ranking) are load-bearing for anyone
designing new perceptual studies.

## Inclusion Decision

**Decision:** Core
**Rationale:** This is the origin paper of the entire encoding-effectiveness research program; every other
source in this card set either replicates it (Heer & Bostock), teaches from it (Munzner), or contests its
generalization (Risks of Ranking). Authority, corroboration, and relevance are all maximal.

**Redundancy check:** Not redundant — it is the primary source that the other four cards in this set discuss,
extend, or challenge. No other card supersedes it, though the Heer & Bostock (2010) card is the best-available
*accessible* empirical re-verification of its core ranking.

**Perspective category:** Academic
