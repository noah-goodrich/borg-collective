# Source: Davis et al. (2022/2023) — "The Risks of Ranking: Revisiting Graphical Perception to Model
Individual Differences in Visualization Performance"

**Full citation:** Davis, Russell, Xiaoying Pu, Yiren Ding, Brian D. Hall, Karen Bonilla, Mi Feng, Matthew Kay,
and Lane Harrison. "The Risks of Ranking: Revisiting Graphical Perception to Model Individual Differences in
Visualization Performance." *IEEE Transactions on Visualization and Computer Graphics (TVCG)*, presented at
IEEE VIS 2022, published 2023.
**URL:** https://arxiv.org/abs/2212.10533
**Date accessed:** 2026-07-28
**Evidence level:** Level 2 (Randomized controlled psychophysics experiment, directly replicating and extending
Cleveland & McGill's original design, analyzed with Bayesian multilevel regression to model individual-level
rather than only average-observer effects)
**Research topic area:** Perception & graphical cognition — the live debate/contrarian challenge to the
canonical Cleveland & McGill encoding-effectiveness ranking

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 8/10 | Lane Harrison (WPI) and Matthew Kay (Northwestern) are established, actively-publishing visualization/HCI researchers; published in TVCG, the top peer-reviewed venue in visualization research, presented at IEEE VIS, the field's flagship conference. |
| 2 | Evidence Quality | 8/10 | Direct replication-and-extension of Cleveland & McGill's own experimental paradigm, analyzed with modern Bayesian multilevel regression specifically designed to detect individual-level deviation from population averages — methodologically more sophisticated than the original 1984 analysis on this specific question. |
| 3 | Currency | 9/10 | Published 2022 (VIS conference) / 2023 (TVCG issue) using contemporary statistical methods — squarely within the "current" tier for this fast-moving methodological debate. |
| 4 | Intent | 9/10 | Pure academic research aimed at improving how the field communicates visualization effectiveness to designers; open data, code, and analysis scripts posted to OSF. |
| 5 | Bias & Objectivity | 8/10 | The paper does not claim the canonical ranking is wrong — it explicitly states its individual-level findings "largely agree with canonical rankings of these visualization types" at the population level, while carefully scoping its critique to the *use* of average-observer rankings for individual-level design decisions. This is a notably even-handed contrarian paper, not a takedown. (Scored on the harder end per bias-guard since I was initially skeptical of the "risk" framing and had to check it wasn't overstating its case.) |
| 6 | Logic & Coherence | 8/10 | The statistical argument (population averages can mask that ~30% of people are not "best with the Bar," i.e., substantial individual deviation from the group-level ranking) is precise and the conclusion follows directly from the multilevel model's variance components. |
| 7 | Corroboration | 6/10 | Builds directly on and is corroborated by the existence of Cleveland & McGill (1984) and Heer & Bostock (2010) as its comparison baseline; the individual-differences critique itself is newer and has fewer independent replications so far, so corroboration for the *novel* claim (not the baseline ranking) is more limited. |
| 8 | Intellectual Honesty | 9/10 | Explicitly and repeatedly hedges its own contribution: it argues the field should move "beyond the use of rankings prevalent in prior work" toward richer distributional reporting, rather than claiming the old ranking is false — a rare, honest scope-limitation for a paper positioned as revisiting a foundational result. |
| 9 | Specificity | 8/10 | Provides a concrete, quantified headline number ("as much as 30% of people are likely not 'best with the Bar'") and names the specific analytical shift it recommends (report full individual-level distributions and log-scale errors, not just average-observer rankings). |
| 10 | Relevance | 9/10 | Directly answers RQ3 (live debates where experts disagree) — this is the clearest, most credible, most recent challenge to the field's default assumption that a single ranking of "what the eye ranks well" applies uniformly to all viewers. |

**Score band:** keep

## Bias Guard Check

- [x] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8 (note: on reflection the
  paper's actual claim is more modest than the provocative title suggests — it does not reject the canonical
  ranking, only its use as a universal individual-level predictor — so this bias-guard direction was applied
  cautiously; see Bias & Objectivity justification above for the harder-scoring counterweight actually used
  once the paper's real scope was understood)

## Key Findings

- Graphical-perception studies conventionally report visualization-encoding effectiveness as the error of an
  "average observer," producing canonical rankings such as position > area > angle > volume — but "different
  people may vary in their ability to read different visualization types, leading to variance in this ranking
  across individuals not captured by population-level metrics."
- Using Bayesian multilevel regression on a replication-and-extension of Cleveland & McGill's own graphical
  comparison experiment, the authors find that "some people show patterns of accuracy that credibly deviate
  from the canonical rankings of visualization effectiveness" — i.e., the "average observer" the classic
  ranking describes may not represent a meaningful fraction of real viewers.
- Quantified headline finding: "as much as 30% of people are likely not 'best with the Bar'" — meaning roughly
  a third of viewers may not perform best with the encoding (bar/position) that the canonical ranking would
  recommend as universally optimal.
- The paper identifies two specific practices it argues the field should retire: (1) reporting visualization
  rankings only for the "average observer," and (2) reporting only aggregate/log error rather than the full
  distribution — both of which "calls into question the value of 'ranking' visualizations" as a one-size-fits-
  all design heuristic.
- Despite the critique, the paper is careful to note its results still "largely agree with canonical rankings of
  these visualization types" at the population level — the debate is about whether individual-level design and
  literacy-support decisions should defer to the average-observer ranking, not whether the ranking is wrong in
  aggregate.

## Verified Quote(s)

**Location reference:** Abstract, p. 1.

> "Graphical perception studies typically measure visualization encoding effectiveness using the error of an
> "average observer", leading to canonical rankings of encodings for numerical attributes: e.g., position > area
> > angle > volume. Yet different people may vary in their ability to read different visualization types,
> leading to variance in this ranking across individuals not captured by population-level metrics using
> "average observer" models."

**Location reference:** Conclusion, section 8, final page (numbered page ~10 of the arXiv PDF).

> "Our work identifies problems with two common practices in visualization research: (1) modeling or reporting
> visualization rankings only for the "average observer" and (2) reporting only log error. The problem with the
> first practice is revealed by our finding that substantial between-individual variance exists for even these
> elementary visualization tasks; e.g., as much as 30% of people are likely not "best with the Bar", and
> different people may depart substantially from the canonical ranking of visualization type effectiveness."

**Location reference:** Conclusion, section 8, final sentence.

> "Ultimately, we believe the field should move beyond the use of rankings prevalent in prior work, building a
> more complete picture of the spectrum of human performance on visualization tasks so that we can create more
> practically-applicable recommendations for visualization designers, and support the important work of
> measuring and promoting visualization literacy."

**Access status:** live — full PDF fetched directly from arXiv and converted to text; all quotes verified
character-for-character against that text.

## Inclusion Decision

**Decision:** Core
**Rationale:** This is the strongest, most recent, most methodologically rigorous credible challenge to the
canonical encoding-ranking consensus found in this research pass — it directly satisfies RQ3's requirement to
surface a live expert debate, and it does so from a peer-reviewed, TVCG/VIS-caliber source rather than an
informal blog take.

**Redundancy check:** Not redundant — no other keeper source in this set questions the canonical ranking's
universality; this is the sole card carrying the "individual differences complicate the average-observer
ranking" side of the live debate, paired against Cleveland & McGill (1984) and Heer & Bostock (2010) as the
"canonical ranking holds" side.

**Perspective category:** Contrarian
