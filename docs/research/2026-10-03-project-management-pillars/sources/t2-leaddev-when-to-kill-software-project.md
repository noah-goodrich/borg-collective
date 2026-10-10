# Source: When to kill a software project (LeadDev, 2026)

**Full citation:** Doerrfeld, Bill. "When to kill a software project." LeadDev. May 28, 2026. https://leaddev.com/leadership/when-to-kill-a-software-project
**URL:** https://leaddev.com/leadership/when-to-kill-a-software-project
**Date accessed:** 2026-10-03
**Evidence level:** 7 (Trade-press synthesis with practitioner quotes)
**Research topic area:** Kill criteria and stopping rules (RQ2)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 5/10 | Trade publication for engineering managers; quotes an SVP of data and AI at a named company. |
| 2 | Evidence Quality | 3/10 | Practitioner quotes and secondary statistics (CHAOS report, Tempo survey) cited but not independently verified here. |
| 3 | Currency | 9/10 | Published May 2026; current. |
| 4 | Intent | 6/10 | Editorial content on a media platform that also sells events; mostly informational. |
| 5 | Bias & Objectivity | 6/10 | Presents a pro-early-kill view but quotes the caveat that fail-fast is debated. |
| 6 | Logic & Coherence | 6/10 | Practical logic: predefine timebox, cost ceiling, confidence threshold; named owner. |
| 7 | Corroboration | 6/10 | Pre-registered stopping criteria also align with Shape Up's circuit breaker and PMI-style guidance. |
| 8 | Intellectual Honesty | 6/10 | Says the fail-fast mantra is debated and that knowing when to pull the plug is tricky. |
| 9 | Specificity | 6/10 | Gives a concrete kill switch (90% confidence on software comparisons) and timebox pattern. |
| 10 | Relevance | 8/10 | Directly about defining kill criteria upfront in software work. |

**Score band:** borderline

(Intermediate weighted average 5.6; the band is the disposition.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Recommended pattern: define exit conditions before starting (timebox, cost ceiling, confidence threshold) and assign a
single decision-owner to make the final call.
- Concrete example: a kill switch of reaching 90% confidence on software-vulnerability matching within a weeks-long
timebox; the team missed it and pivoted rather than extend.
- Reports (via secondary citation) that only 31% of software projects succeed and 19% are canceled before production
(CHAOS) and that teams canceling more projects deliver better outcomes (Tempo 2026), both unverified here.
- Treat percentages as claims to verify; the CHAOS report methodology is widely contested.

## Verified Quote(s)

**Location reference:** Quote 1: "Key takeaways" box at the top of the article, first bullet of the list. Quote 2:
section "Set kill criteria upfront and timebox it", paragraph 5 (counting body paragraphs after that heading, excluding
lists; it begins "Our kill switch was whether").

Card revised: 2026-10-03 (location audit before re-verification)

> Set kill criteria before you start. Define your exit conditions upfront – a timebox, a cost ceiling, a confidence threshold.

> “Our kill switch was whether we could get to a 90% confidence on software comparisons,” explains Carusone.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Current practitioner statement of kill-criteria practice that complements the academic escalation evidence.
Borderline: stats secondary and the source is trade press.

**Redundancy check:** PMI and APM pages seen in search were not fetched (access errors) and are cited only in the search log.

**Perspective category:** Practitioner
