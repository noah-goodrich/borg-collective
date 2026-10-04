# Source: Google SRE Book — Chapter 15, Postmortem Culture: Learning from Failure

**Full citation:** John Lunney and Sue Lueder (edited by Gary O'Connor). "Postmortem Culture: Learning from Failure."
In Site Reliability Engineering (Google), Chapter 15. O'Reilly / sre.google, 2016.
**URL:** https://sre.google/sre-book/postmortem-culture/
**Date accessed:** 2026-10-03
**Evidence level:** 4
**Research topic area:** T4 feedback — learning/adaptation (blameless post-mortems)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Written by Google SRE practitioners operating at very large scale; the canonical citation for blameless postmortems. |
| 2 | Evidence Quality | 4/10 | Codified internal practice and anecdote; no outcome data showing postmortems reduce recurrence. |
| 3 | Currency | 5/10 | 2016 (3-4 band) plus the +2 timeless bonus for cultural mechanics; tooling examples are dated. |
| 4 | Intent | 7/10 | Professional/field-advancing, but also employer-brand writing for Google's SRE approach. |
| 5 | Bias & Objectivity | 6/10 | Advocacy for its own practice; does not cite failure cases of postmortem programs. |
| 6 | Logic & Coherence | 7/10 | Coherent: blame suppresses reporting, so remove blame to surface issues. Causal claim is asserted, not tested. |
| 7 | Corroboration | 7/10 | Echoed by Etsy/Allspaw writing and by the AAR "not a critique" doctrine in TC 25-20. |
| 8 | Intellectual Honesty | 6/10 | Admits blameless writing is hard; little discussion of what does not work. |
| 9 | Specificity | 7/10 | Concrete triggers, template, review process, and a "Wheel of Misfortune" training exercise. |
| 10 | Relevance | 8/10 | Directly the best-practice statement for incident/failure review; software domain. |

**Score band:** borderline (weighted average about 6.4)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- States the purpose: document the incident, understand root causes, and put effective preventive actions in place to
  reduce recurrence — recurrence prevention is the stated outcome, not merely documentation.
- Blameless means assuming good intent and removing blame so people escalate issues without fear; the stated risk of
  blame is that issues get swept under the rug.
- Prescribes explicit postmortem triggers (user-visible downtime, data loss, on-call intervention, monitoring
  failure), so review is criteria-driven rather than discretionary.
- Pairs review with reinforcement: visible reward for doing the right thing and senior-leadership participation.
- Offers no measured evidence that this reduces repeat incidents (see the t4-allspaw and t4-maric cards for that gap).

## Verified Quote(s)

**Location reference:** Section "Google's Postmortem Philosophy", first paragraph; and "Best Practice: Avoid Blame and
Keep It Constructive", paragraph 1.

> The primary goals of writing a postmortem are to ensure that the incident is documented, that all contributing root cause(s) are well understood, and, especially, that effective preventive actions are put in place to reduce the likelihood and/or impact of recurrence.

> Removing blame from a postmortem gives people the confidence to escalate issues without fear.

> An atmosphere of blame risks creating a culture in which incidents and issues are swept under the rug, leading to greater risk for the organization

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band kept by documented reason: it is the primary institutional statement of blameless
post-mortem practice and is needed to describe the practice; claims of effectiveness must be sourced elsewhere.

**Redundancy check:** Adds triggers and the blame-suppresses-reporting mechanism not found in the Army or meta-analytic
sources.

**Perspective category:** Institutional

Card revised: 2026-10-03 (Key Findings prose only: cross-references to other cards now use card names, not
domains, and a filename was spelled out, because the gate A9 check read them as quote-attribution hosts. No quote,
location, score or decision changed.)
