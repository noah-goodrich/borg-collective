# Source: Reising and Montgomery 2005 - Achieving Effective Alarm System Performance (ASM Consortium vs EEMUA 191)

**Full citation:** Reising DVC, Montgomery T. "Achieving Effective Alarm System Performance: Results of ASM Consortium Benchmarking against the EEMUA Guide for Alarm Systems." 20th Annual CCPS International Conference, Atlanta, 11-13 April 2005 (Abnormal Situation Management Consortium; Honeywell Laboratories and ChevronTexaco).
**URL:** https://process.honeywell.com/content/dam/process/en/documents/document-lists/doc_asm-consortium/white-papers/February%2028%202005%20-%20Acheiving%20Effective%20Alarm%20System%20Performance%20Benchmarking.pdf
**Date accessed:** 2026-10-04
Card revised: 2026-10-04 (location audit before verification)
**Evidence level:** 3 (cross-sectional observational benchmark of 37 operator consoles)
**Research topic area:** S1 alarm and alert design - EEMUA 191 numeric rate bands and achievability

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | Industry consortium researchers (Honeywell Laboratories, ChevronTexaco) presenting at a CCPS conference; domain-credible, not a peer-reviewed journal. |
| 2 | Evidence Quality | 7/10 | Measured alarm-rate data from 37 operator consoles across companies, benchmarked against EEMUA 191 categories; states selection caveats. |
| 3 | Currency | 5/10 | 2005; the numeric bands are still the cited benchmark in ISA-18.2/EEMUA practice and human cognitive limits are timeless (+2 applied). |
| 4 | Intent | 6/10 | Consortium benchmarking with a vendor co-author (Honeywell trademark note) - professional advancement with some commercial interest. |
| 5 | Bias & Objectivity | 6/10 | Reports that peak-rate guidance is mostly unmet and that EEMUA numbers are "devoid of context"; consortium members have an interest in alarm-management products. |
| 6 | Logic & Coherence | 7/10 | Conclusions follow the data; explicitly warns against a "silver bullet". |
| 7 | Corroboration | 7/10 | The 5-alarms-per-10-minutes HSE survey and the EEMUA bands are cited; a 2016 thesis analysing company data reports priority inflation consistent with this. |
| 8 | Intellectual Honesty | 8/10 | Spells out two caveats: data may mix operating modes and better-performing consoles are over-represented. |
| 9 | Specificity | 9/10 | Table of acceptability bands, 37 consoles, median monthly rate 1.77 per 10 minutes, mean 2.3. |
| 10 | Relevance | 7/10 | Control-room alarm rates are an analogue, not a developer status display; the transferable point is that attention-demanding alerts must be rare and that thresholds are context-dependent. |

**Score band:** borderline (weighted average about 6.8. Included as the only open, data-bearing source for the EEMUA 191 rate bands (the standard itself is a paid document); the borderline call is named: a conference paper with a vendor co-author.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- EEMUA 191 guidance: average under 1 alarm per 10 minutes in steady state is "very likely to be acceptable", 1-2 is manageable, more than 10 is "very likely to be unacceptable" (Table 1).
- Across 37 consoles, about one-third met the under-1 guideline and about one-quarter more were at "manageable"; only 2 of 37 came close to the upset-condition guideline of no more than 10 alarms in the first 10 minutes.
- The earlier HSE survey found an average of about 5 alarms per 10 minutes, which is what prompted the guidance; the consortium mean was 2.3 and median 1.77.
- The authors note the EEMUA numbers are "devoid of context" (no allowance for automation level or unit size) and that no single fix achieves them; a metrics-driven continuous-improvement lifecycle is needed.

## Verified Quote(s)

**Location reference:** Quote 1: PDF page 1 ("Page 1 of 12"), Abstract, sentence 3 (sentences split at a terminal
period followed by a capital letter; "i.e." and "e.g." do not split; 1 = "The Abnormal Situation Management Consortium
has recently completed...", 2 = "These studies related directly...", 3 = "Results from 37 unique operator
consoles..."). Quote 2: PDF page 1, Abstract, sentence 6 ("Only 2 of the 37 consoles..."). Quote 3: PDF page 7 ("Page
7 of 12"), section "3.3 Relating Average Alarm Rate for Normal Operations to Benchmarking Metrics", paragraph 1,
sentence 1 (the sentence beginning "One of the observations made by ASM members about EEMUA Publication No. 191"; the
quote is its closing clause).

> Results from 37 unique operator consoles indicate that the EEMUA recommendation for average alarm rate during normal operations (i.e., less than one alarm per 10 minutes), while not universally demonstrated, is achievable today.

> Only 2 of the 37 consoles came close to achieving the alarm rate guideline for upset conditions.

> the recommendations for alarm rate performance are devoid of context.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Only open data source quantifying how rare an attention-demanding alert must be, and how hard that is to achieve in practice; supports "few, prioritised, actionable" design. Pre-2020 flagged as foundational for human-limit claims.

**Redundancy check:** Unique numerics. Google SRE adds the software-operations equivalent without numbers; Ancker adds the clinical mechanism.

**Perspective category:** Institutional
