# Source: Few 2007 - Dashboard Design for Real-Time Situation Awareness

**Full citation:** Few S. "Dashboard Design for Real-Time Situation Awareness." Perceptual Edge white paper (published with Inova Solutions). Copyright 2007.
**URL:** http://www.perceptualedge.com/articles/Whitepapers/Dashboard_Design.pdf
**Date accessed:** 2026-10-04
**Evidence level:** 7 (practitioner expert synthesis; no new data)
**Research topic area:** S1 status displays and situational awareness - dashboard design mapped to Endsley levels 1-3

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | Stephen Few is the best-known dashboard-design practitioner and author of Information Dashboard Design; not an academic and not an SA researcher (he cites Endsley, Bolte and Jones for the definition). |
| 2 | Evidence Quality | 4/10 | Design argument plus annotated examples (call-center monitoring); no experiments or measured outcomes. Rests on cited vision and working-memory science. |
| 3 | Currency | 4/10 | 2007; interface technology has moved but the working-memory and salience arguments are timeless (+2 bonus applied). |
| 4 | Intent | 4/10 | Published as a white paper for Inova Solutions, a dashboard vendor (the PDF ends with a vendor boilerplate), and it advances Few's consulting/book brand. |
| 5 | Bias & Objectivity | 5/10 | Strongly opinionated about what a dashboard is; does not cite counter-evidence, though it does state that user expertise and mental model are prerequisites. |
| 6 | Logic & Coherence | 7/10 | Clear chain from the three SA levels to concrete design rules (context, salience, projection via sparklines). |
| 7 | Corroboration | 7/10 | Alarm restraint is independently supported by the ASM/EEMUA benchmark and the Google SRE book; the working-memory claim by Cowan-type limits (see c1 cards); the dashboard-effectiveness claim is only conditionally supported (Xie 2022). |
| 8 | Intellectual Honesty | 7/10 | States that a perfect dashboard cannot overcome user inexpertise and that complexity limits depend on the audience; admits some displays fail at any amount of information. |
| 9 | Specificity | 7/10 | Named failure modes (too much complexity, too many alert conditions, inappropriate salience, not enough context), numeric guidance (no more than two alert types) and annotated figures. |
| 10 | Relevance | 10/10 | It is the one source that maps Endsley's perception/comprehension/projection onto a single-screen status display design, which is exactly the borg link question. |

**Score band:** borderline (weighted average about 5.8. Included on a documented reason: it is the only practitioner source that translates the three SA levels into display-design rules, and its alarm-restraint and context claims are corroborated by sources with stronger evidence (Reising 2005, Google SRE, Ancker 2017).)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A status display must support all three SA levels - perception, comprehension, projection - and failure at any level undermines it (PDF p. 3).
- Putting everything to be monitored on one screen works because it offloads short-term memory (about four chunks) onto the display, which acts as external memory (PDF p. 6).
- Colour/alarm restraint: reserve visual or auditory attention-grabbing for information that urgently requires a response; scoring every item good/bad drowns the few items needing attention; use at most two alert types (PDF pp. 7, 9, 11).
- Numbers alone do not give comprehension: show the target, prior period or history beside each measure (PDF p. 15) and give enough history (sparklines) to spot adverse trends, which is how the paper operationalises projection (PDF p. 19).
- The author caveats that the user must already hold a domain mental model; the display cannot supply expertise.

## Verified Quote(s)

**Location reference:** Quote 1: PDF p. 3 (PDF page index equals the printed folio), under the heading "Situation Awareness", the paragraph beginning "A dashboard that is designed to support situation awareness", sentence 1. Paragraphs counted as blank-line-separated blocks; figure captions skipped. Quote 2: PDF p. 6, under the heading "The Benefits of Bringing Information Together Within Eye Span", the paragraph beginning "By placing all of the information", sentence 1. Quote 3: PDF p. 7, under the heading "Too many alert conditions", paragraph 2 (beginning "Only use visual or auditory means"), sentence 1. Quote 4: PDF p. 15, under the heading "Not enough context", paragraph 1, sentence 4 (sentences counted from "Numbers all by themselves aren't very helpful for monitoring performance."). Quote 5: PDF p. 19, under the heading "Support projections for proactive responses", paragraph 2 (beginning "One of the best and easiest ways"), sentence 1.

> A dashboard that is designed to support situation awareness must support all three levels of awareness.

> By placing all of the information that you need to monitor (at least at a high level) on a single screen, simultaneously available to our eyes, we work around the limitations of short term memory by reducing the need to rely on it.

> Only use visual or auditory means to draw attention to information that urgently requires a response.

> Many dashboards fail by providing too little context for making sense of the numbers that they present.

> One of the best and easiest ways to support this need is by providing enough historical context for people to easily spot trends that are heading in the wrong direction.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline on the rubric; kept because nothing else in the corpus ties Endsley's three levels to concrete display rules. Secondary perspective: also Institutional-adjacent (vendor white paper), but primary category is Practitioner.

**Redundancy check:** Unique: the SA-to-dashboard mapping. Few's pre-attentive article (c1 card) covers perception attributes only and does not overlap.

**Perspective category:** Practitioner
