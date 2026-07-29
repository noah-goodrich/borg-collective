# Source: Heer & Bostock (2010) — "Crowdsourcing Graphical Perception: Using Mechanical Turk to Assess
Visualization Design"

**Full citation:** Heer, Jeffrey, and Michael Bostock. "Crowdsourcing Graphical Perception: Using Mechanical
Turk to Assess Visualization Design." *Proceedings of the SIGCHI Conference on Human Factors in Computing
Systems (CHI 2010)*, ACM, 2010, pp. 203-212. (Best Paper nominee.)
**URL:** http://vis.stanford.edu/papers/crowdsourcing-graphical-perception
**Date accessed:** 2026-07-28
**Evidence level:** Level 2 (Randomized controlled psychophysics experiment; large online subject pool with
randomized task assignment, directly replicating a prior controlled experiment)
**Research topic area:** Perception & graphical cognition — modern replication of the Cleveland & McGill
encoding-effectiveness ranking, extended to new judgment types (rectangular area, chart size, gridlines)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 9/10 | Jeffrey Heer (then Stanford, later UW) is one of the most cited living visualization researchers (D3.js, Vega, Protovis); Michael Bostock co-created D3.js. Published at CHI, the top human-computer-interaction venue, and was a Best Paper nominee. |
| 2 | Evidence Quality | 8/10 | Large-N crowdsourced psychophysics experiment (hundreds of Mechanical Turk subjects per condition) with randomized task assignment and a pre-registered replication design against Cleveland & McGill's original tasks — stronger N than the 1984 original, though crowdsourced conditions sacrifice some environmental control (display size, viewing distance). |
| 3 | Currency | 6/10 | Published 2010, now 16 years old; the crowdsourcing-methodology parts are dated (Mechanical Turk demographics and pay norms have shifted), but the perceptual replication findings are treated as current baseline knowledge in visualization pedagogy as of 2026. |
| 4 | Intent | 9/10 | Academic methods paper validating a research tool (MTurk) and reporting new perceptual findings; no commercial motive. |
| 5 | Bias & Objectivity | 8/10 | The paper explicitly reports where their results diverge from Cleveland & McGill (e.g., a note that C&M did not find angle performing worse than length in one case) rather than only reporting confirmatory results. (Scored on the harder end per bias-guard since I broadly expected confirmation.) |
| 6 | Logic & Coherence | 8/10 | Methodology (replicate old study first to validate the new platform, then extend to novel judgment types) is a textbook-clean research design; conclusions follow from reported log-error data. |
| 7 | Corroboration | 8/10 | Corroborates Cleveland & McGill (1984) directly; itself corroborated by later citations across the visualization literature (e.g., Munzner's textbook, "Risks of Ranking" 2022 uses the same experimental paradigm). |
| 8 | Intellectual Honesty | 8/10 | Explicitly flags limits of crowdsourcing (loss of control over display type, size, lighting, viewing distance/angle) as a stated methodological caveat rather than glossing over it. |
| 9 | Specificity | 9/10 | Reports concrete log-error statistics, aspect-ratio manipulations for rectangular-area judgments, and specific chart-size/gridline-spacing findings — highly reproducible and concrete. |
| 10 | Relevance | 10/10 | This is the primary modern empirical replication of the core encoding-ranking claim the track is investigating, and it is fully open-access (unlike the 1984 original). |

**Score band:** keep

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8

## Key Findings

- Crowdsourced perception experiments on Amazon Mechanical Turk are viable: results replicating Cleveland &
  McGill's original spatial-encoding and luminance-contrast studies "match previous work, are consistent with
  theoretical predictions, and suggest that crowdsourcing is viable for testing graphical perception."
- The paper reports one notable divergence from the original 1984 findings: Cleveland & McGill did not find
  angle performing worse than length in one comparison, whereas the MTurk replication's results differed on
  this specific point — an early, credible crack in treating the original ranking as universally exact rather
  than directionally correct.
- New experiments on rectangular area judgments (as used in treemaps and cartograms) found that extreme
  aspect-ratio variation hampers area estimation accuracy, directly informing the design of "squarified"
  treemap layouts — extending the Cleveland & McGill program to a modern visualization idiom the 1984 paper
  never tested.
- New experiments on chart size and gridline spacing provide practical, quantified guidance (not present in the
  1984 paper) for how much display real estate and gridline density actually help decoding accuracy.
- Practical/methodological finding for researchers: qualification tasks and verifiable questions improve
  response quality on crowdsourced platforms, and increasing compensation accelerates time-to-results —
  useful for anyone designing a follow-up perception study today.

## Verified Quote(s)

**Location reference:** Abstract, first page (p. 203 of the CHI 2010 proceedings; page 1 of the archived PDF).

> "In this paper, we assess the viability of Amazon's Mechanical Turk as a platform for graphical perception
> experiments. We replicate previous studies of spatial encoding and luminance contrast and compare our
> results. We also conduct new experiments on rectangular area perception (as in treemaps or cartograms) and on
> chart size and gridline spacing. Our results demonstrate that crowdsourced perception experiments are viable
> and contribute new insights for visualization design."

**Location reference:** "Experiment 1A" results discussion, PDF page ~3 (section following Figure re: position-
angle comparison).

> "Cleveland & McGill also did not find angle to perform worse [...]"

**Access status:** live — full PDF fetched and converted to text directly from an openly hosted course-syllabus
mirror of the Stanford Vis Group PDF; quotes verified character-for-character against that text.

## Inclusion Decision

**Decision:** Core
**Rationale:** Best available fully open-access, large-sample modern replication of the foundational ranking;
directly answers RQ2/RQ3 (canon + evidence for how well the original findings hold up) with concrete,
verifiable data.

**Redundancy check:** Not redundant with Cleveland & McGill (1984) — it re-tests and extends that paper's
claims with a different, larger, more accessible dataset, and is not redundant with "Risks of Ranking" (2022),
which targets individual-difference variance rather than platform/methodology validation.

**Perspective category:** Academic
