# Source: Ancker et al. 2017 - Effects of workload, work complexity, and repeated alerts on alert fatigue

**Full citation:** Ancker JS, Edwards A, Nosal S, Hauser D, Mauer E, Kaushal R. "Effects of workload, work complexity, and repeated alerts on alert fatigue in a clinical decision support system." BMC Medical Informatics and Decision Making 17:36. 2017. https://doi.org/10.1186/s12911-017-0430-8
**URL:** https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:10.1186/s12911-017-0430-8&resultType=core&format=json
**Date accessed:** 2026-10-04
Card revised: 2026-10-04 (location audit before verification)
**Evidence level:** 3 (large retrospective cohort, 112 clinicians)
**Research topic area:** S1 alarm and alert design - mechanisms of alert fatigue

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Peer-reviewed in BMC Medical Informatics and Decision Making by a clinical-informatics author group. |
| 2 | Evidence Quality | 7/10 | Retrospective cohort of 112 primary-care clinicians over about 3.5 years, regression on acceptance; observational, so causation is inferred. |
| 3 | Currency | 6/10 | 2017 (+2 timeless for cognitive mechanism). |
| 4 | Intent | 9/10 | Academic. |
| 5 | Bias & Objectivity | 8/10 | Tests two competing mechanisms and reports the one not supported. |
| 6 | Logic & Coherence | 8/10 | Hypotheses map directly to analyses. |
| 7 | Corroboration | 7/10 | Aligned with the alarm-load literature and with the SRE view that repeated non-actionable pages degrade response. |
| 8 | Intellectual Honesty | 8/10 | Notes the concept of alert fatigue is "poorly defined" and that desensitization was not supported. |
| 9 | Specificity | 9/10 | Quantifies: each extra reminder per encounter cut acceptance likelihood by 30%. |
| 10 | Relevance | 6/10 | Clinical alerts, not developer status; the transferable finding is that repeats and complexity, not raw volume of work, drive disregard. |

**Score band:** keep (weighted average about 7.6. This is the lowest-scoring source that cleared the keep bar in this track.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- About one-quarter of drug alerts and one-third of clinical reminders were repeats for the same patient within the same year.
- Alert acceptance was associated with work complexity and repeated alerts but not with the amount of work.
- Each additional reminder per encounter reduced the likelihood of acceptance by 30%; each five-point rise in the proportion of repeated reminders cut it by 10%.
- No evidence of desensitization over time for newly deployed reminders; the data point to low-information repeats as the lever, so suppressing within-item repeats is the promising fix.

## Verified Quote(s)

**Location reference:** Quote 1: Abstract, Results section, sentence 3 (overall abstract sentence 8). Quote 2:
Abstract, Conclusions section, sentences 1-2 (overall sentences 11-12). Counting rule: the abstract text in the card
URL's `abstractText` field is split at a terminal period or question mark followed by a capital letter; section labels
are not sentences. Section ordinals count within the labelled section; overall ordinals count from the first abstract
sentence, with each label belonging to the sentence that follows it. Snapshot:
docs/research/snapshots/s1-ancker-2017-alert-fatigue.txt

> Likelihood of reminder acceptance dropped by 30% for each additional reminder received per encounter, and by 10% for each five percentage point increase in proportion of repeated reminders.

> Clinicians became less likely to accept alerts as they received more of them, particularly more repeated alerts. There was no evidence of an effect of workload per se, or of desensitization over time for a newly deployed alert.

**Access status:** cached/partial

Access note: Abstract only, via the Europe PMC REST API (PMCID PMC5387195, open access), snapshotted; full text not read.  Card URL changed 2026-10-04 from the DOI landing page (publisher host blocks automated fetch) to the Europe PMC REST record, on which the quotes were re-verified.

## Inclusion Decision

**Decision:** Core
**Rationale:** Best empirical evidence on why alerts get ignored: repetition and low informational value, not just volume.

**Redundancy check:** Unique mechanism evidence; complements Reising (rates) and SRE (actionability).

**Perspective category:** Academic
