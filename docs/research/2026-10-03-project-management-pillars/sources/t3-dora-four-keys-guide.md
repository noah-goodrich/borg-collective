# Source: DORA: Software delivery performance metrics (four/five keys) guide and pitfalls

**Full citation:** DORA. "DORA's software delivery metrics: the four keys." dora.dev guide. Last updated 2026-01-05.
**URL:** https://dora.dev/guides/dora-metrics-four-keys/
**Date accessed:** 2026-10-03
**Evidence level:** 4 (Expert consensus / professional body guidance)
**Research topic area:** DORA metrics definition; Goodhart and gaming (RQ3)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Maintained by the DORA team (Google Cloud); authoritative on its own definitions. |
| 2 | Evidence Quality | 5/10 | Guidance document grounded in the DORA research programme, with no new data presented. |
| 3 | Currency | 9/10 | Updated Jan 2026. |
| 4 | Intent | 6/10 | Free guide intended to help adoption; sponsor benefits indirectly. |
| 5 | Bias & Objectivity | 7/10 | Lists its own metric's misuse risks, which is rare for a metric owner. |
| 6 | Logic & Coherence | 7/10 | Definitions and pitfalls are consistent. |
| 7 | Corroboration | 8/10 | Independent critics (Lee, Beck/Orosz, InfoQ) make the same Goodhart point. |
| 8 | Intellectual Honesty | 7/10 | Names Goodhart's law and a list of misuse pitfalls; stops short of questioning validity of the underlying survey. |
| 9 | Specificity | 7/10 | Gives concrete example target ('Every application must deploy multiple times per day by year's end'). |
| 10 | Relevance | 10/10 | Defines the metrics and their gaming failure modes (RQ3). |

**Score band:** keep
(Intermediate weighted average ~7.2; the band is the disposition.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- DORA now defines five metrics: change lead time, deployment frequency, failed deployment recovery time (throughput) plus change fail rate and deployment rework rate (instability).
- DORA lists 'Setting metrics as a goal' as a named pitfall and cites Goodhart's law, saying broad targets increase the likelihood that teams try to game the metrics.
- Other listed pitfalls include relying on a single metric, comparing across disparate applications, siloed ownership of metrics and competition between teams.
- The metric owner thus endorses using the keys as team-owned diagnostic measures, not targets.

## Verified Quote(s)

**Location reference:** https://dora.dev/guides/dora-metrics-four-keys/, section "Common pitfalls", first bullet of the
list ("Setting metrics as a goal."), which follows the one-line intro "There are some pitfalls to watch out for".

Card revised: 2026-10-03 (location audit before re-verification)

> Setting metrics as a goal. Ignoring Goodhart’s law and making broad statements like, “Every application must deploy multiple times per day by year’s end,” increases the likelihood that teams will try to game the metrics.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Primary source for RQ3 from the metric owner; also fixes definitions.

**Redundancy check:** Unique as owner's own pitfall list; the Lee and Beck cards give outside views.

**Perspective category:** Institutional
