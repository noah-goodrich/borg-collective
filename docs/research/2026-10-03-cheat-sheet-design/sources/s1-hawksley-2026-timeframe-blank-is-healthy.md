# Source: Hawksley 2026 - How I built Timeframe, our family e-paper dashboard

**Full citation:** Hawksley J. "How I built Timeframe, our family e-paper dashboard." hawksley.org, 2026-02-17. Discussed at Hacker News item 47113728.
**URL:** https://hawksley.org/2026/02/17/timeframe.html
**Date accessed:** 2026-10-04
**Evidence level:** 8 (personal experience over a decade of iteration)
**Research topic area:** S1 status displays - a personal always-on status display that shows only exceptions

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 4/10 | Software engineer building for his own household over ten years; no independent verification of qualifications or results. |
| 2 | Evidence Quality | 2/10 | Single-household anecdote, no measurements. |
| 3 | Currency | 9/10 | February 2026. |
| 4 | Intent | 7/10 | Hobby project write-up, with a stated intention to bring a product to market. |
| 5 | Bias & Objectivity | 5/10 | Enthusiast; reports hardware and reliability problems candidly but not failures of the design principle. |
| 6 | Logic & Coherence | 7/10 | Argues that separating control from status display enables an exception-only display. |
| 7 | Corroboration | 4/10 | The blank-means-healthy idea matches the alarm-management principle that normal states should not demand attention (Few; Google SRE), but those do not corroborate the household result. |
| 8 | Intellectual Honesty | 7/10 | Lists unresolved hardening, cost and integration issues. |
| 9 | Specificity | 6/10 | Describes the specific mechanism (top-left status area is blank when nothing needs attention) and examples (open doors, laundry done). |
| 10 | Relevance | 6/10 | A personal ambient status display used continuously for years, the nearest lived analogue to a one-developer status page. |

**Score band:** borderline (weighted average about 5.0 (borderline floor). Included only as the boots-on-the-ground perspective; it is anecdote and carries hypothesis weight only.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- After years of iteration the household display reserves one corner as a status area that is blank when nothing needs attention.
- The author argues showing only what is relevant at the moment contradicts how most smart-home apps present status, and removes the need to scan a whole screen.
- The design is feasible because control of devices was separated from display of their status - the display is read-only.
- Earlier iterations (magic mirror, OLED) were abandoned partly because a bright, always-on display was distracting; low-distraction e-paper was the design that stuck.

## Verified Quote(s)

**Location reference:** Quote 1: Section "Today", prose paragraph 3 (counting prose paragraphs under the heading, skipping figures, video fallback text and captions: 1 "Since moving into our new home...", 2 "Or whether the laundry is done:", 3 this one), sentence 1. Quote 2: Section "Today", prose paragraph 4 (beginning "The single status indicator removes"), sentence 1.

> It has a powerful function: if the status on the display is blank, the house is in a "healthy" state and does not need any attention.

> The single status indicator removes the need to scan an entire screen.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline floor; kept for perspective coverage and because the exception-only pattern is the single most design-relevant practitioner idea for a status page. The weakest source in the track that was kept.

**Redundancy check:** Anecdotal restatement of Few's "if things are fine, don't draw attention" principle with a long-run personal-use case.

**Perspective category:** Boots-on-the-ground
