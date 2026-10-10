# Source: Google SRE Book - Monitoring Distributed Systems (alerts, pages, over-alerting case)

**Full citation:** Beyer B, Jones C, Petoff J, Murphy NR (eds). "Monitoring Distributed Systems" (chapter 6, authored by Rob Ewaschuk). Site Reliability Engineering, O'Reilly/Google. 2016. Free online edition.
**URL:** https://sre.google/sre-book/monitoring-distributed-systems/
**Date accessed:** 2026-10-04
**Evidence level:** 5 (practitioner experience with case descriptions; no controlled data)
**Research topic area:** S1 alarm and alert design - actionable alerts, over-alerting, pager fatigue

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Written by practising Google SREs who run on-call at very large scale; widely treated as canonical in operations. |
| 2 | Evidence Quality | 3/10 | Experiential case studies (Bigtable, Gmail) and stated philosophy; no measurements of outcomes. |
| 3 | Currency | 5/10 | 2016; the philosophy has been durable and the chapter is still hosted unchanged (timeless-ish bonus applied). |
| 4 | Intent | 7/10 | Knowledge sharing, though also employer-brand building for Google SRE. |
| 5 | Bias & Objectivity | 6/10 | Presents one organisation's approach as the standard; calls its own stance "aspirational". |
| 6 | Logic & Coherence | 8/10 | Questions-to-ask list follows directly from the stated philosophy. |
| 7 | Corroboration | 8/10 | Consistent with EEMUA/ASM alarm-rate evidence (Reising 2005) and clinical alert-fatigue findings (Ancker 2017) that repeated low-value alerts reduce responsiveness. |
| 8 | Intellectual Honesty | 7/10 | Calls the philosophy "a bit aspirational" and discusses trade-offs, e.g. dialling back an SLO target to regain breathing room. |
| 9 | Specificity | 7/10 | Concrete five-question checklist and named cases with remedies. |
| 10 | Relevance | 8/10 | Directly addresses which signals deserve to interrupt a human and what to do when too many do. |

**Score band:** borderline (weighted average about 6.3. Included on a documented reason: the clearest practitioner statement of the actionable-or-it-is-not-a-page rule, corroborated by higher-evidence alarm studies.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Alert test: does the rule detect an otherwise undetected condition that is urgent, actionable and actively or imminently user-visible? Otherwise it should not interrupt a human.
- Fatigue limit: "I can only react with a sense of urgency a few times a day before I become fatigued"; a robotic response means it should be automation, not a page.
- Bigtable case: voluminous email and paging alerts consumed engineering time; the team had to triage to find the few actionable ones and missed user-affecting problems; fix was to dial back the target and disable the email alerts.
- Pages with rote, algorithmic responses are a red flag to be automated away, not tolerated.

## Verified Quote(s)

**Location reference:** Quote 1: Section "Tying These Principles Together", the bulleted philosophy list that follows "These questions reflect a fundamental philosophy on pages and pagers:", bullet 1, sentences 1-2. Quote 2: Same section and list, bullet 3, sentences 1-2. Quote 3: Section "Bigtable SRE: A Tale of Over-Alerting", paragraph 2 (beginning "Email alerts were triggered as the SLO approached"), sentence 2. Paragraphs counted from "Google’s internal infrastructure..." as paragraph 1.

> Every time the pager goes off, I should be able to react with a sense of urgency. I can only react with a sense of urgency a few times a day before I become fatigued.

> Every page response should require intelligence. If a page merely merits a robotic response, it shouldn’t be a page.

> the team spent significant amounts of time triaging the alerts to find the few that were really actionable, and we often missed the problems that actually affected users, because so few of them did.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline on evidence; adds the practitioner voice and the operational definition of actionable. Secondary perspective: also boots-on-the-ground in the Bigtable case, but the chapter is a curated book.

**Redundancy check:** Overlaps Few's alarm-restraint rule in principle but is the only source with an actionability test and a worked over-alerting case.

**Perspective category:** Practitioner
