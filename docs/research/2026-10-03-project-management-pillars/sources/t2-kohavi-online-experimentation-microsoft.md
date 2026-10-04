# Source: Online Experimentation at Microsoft (Kohavi et al., ThinkWeek 2009)

**Full citation:** Kohavi, R., Frasca, B., Crook, T., Henne, R., Longbotham, R., Lavista Ferres, J., Melamed, T. "Online Experimentation at Microsoft." Microsoft ThinkWeek paper (public version). 2009. http://ai.stanford.edu/~ronnyk/ExPThinkWeek2009Public.pdf
**URL:** http://ai.stanford.edu/~ronnyk/ExPThinkWeek2009Public.pdf
**Date accessed:** 2026-10-03
**Evidence level:** 5 (Practitioner case data from a large experimentation platform)
**Research topic area:** Does a-priori prioritization beat evidence? Value measurement (RQ2, RQ3)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Authors run Microsoft's Experimentation Platform; Kohavi is a widely cited authority on controlled experiments; paper recognized top-30 in ThinkWeek. |
| 2 | Evidence Quality | 7/10 | Randomized controlled experiments on live web properties at scale, aggregated into success rates; the paper reports figures but not a full dataset. |
| 3 | Currency | 5/10 | 2009 paper; the one-third figure has been repeated in later Kohavi publications, giving a timeless component (+2 applied). |
| 4 | Intent | 7/10 | Internal advocacy for experimentation but written for knowledge-sharing, with published candid failure rates. |
| 5 | Bias & Objectivity | 6/10 | Pro-experimentation stance; nonetheless reports the humbling base rates against the authors' own product teams. |
| 6 | Logic & Coherence | 8/10 | Chain from experiment outcomes to the implication "most ideas fail to show value" is direct. |
| 7 | Corroboration | 8/10 | Paper cites other firms (e.g., Netflix, Quicken Loans anecdotes) and later literature reports sub-50% success rates. |
| 8 | Intellectual Honesty | 8/10 | Notes many Microsoft staff dismissed the statistics when first shared and discusses cultural resistance. |
| 9 | Specificity | 8/10 | Concrete case studies (MSN, Office, search) with named experiments and rates. |
| 10 | Relevance | 8/10 | Tests a core assumption of prioritization scoring: that a-priori judgments of value are reliable. |

**Score band:** keep

(Intermediate weighted average 7.2; the band is the disposition.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Of well-designed experiments meant to improve a key metric, only about one third succeeded at doing so; so a-priori
value estimates are right a minority of the time.
- The authors explicitly say their results question whether a-priori prioritization is as good as most people believe,
which cuts against over-trusting any scoring method.
- Recommended response is cheap early tests and stopping launches that are flat or negative, i.e., a measured-outcome
stopping rule rather than a better forecast.
- Scope caveat: results come from web products with large traffic and controllable randomization; a solo developer
cannot run such experiments, so the transferable lesson is the base rate, not the method.

## Verified Quote(s)

**Location reference:** http://ai.stanford.edu/~ronnyk/ExPThinkWeek2009Public.pdf (PDF page numbers). Quote 1: PDF page
1, Abstract, sentence 6 (counting sentences from the start of the abstract; it follows "In our previous papers, we did
not have good examples of controlled experiments at Microsoft; now we do!"). Quote 2: PDF page 8, Section 5.1 "Most
Ideas Fail to Show Value", paragraph 3 (beginning "When we first shared some of the above statistics at Microsoft"),
sentences 2-3.

Card revised: 2026-10-03 (location audit before re-verification)

> The humbling results we share bring to question whether a-priori prioritization is as good as most people believe it is.

> Evaluating well-designed and executed experiments that were designed to improve a key metric, only about one-third were successful at improving the key metric!

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Strongest available empirical datum on how reliable prior value estimates are, which grounds RQ3 (measurement) and the
case for outcome-based stopping. Older (2009) but corroborated and timeless.

**Redundancy check:** Not redundant with the scoring-method sources: it is the only outcome-base-rate evidence.

**Perspective category:** Academic
