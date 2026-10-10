# Citation Verification Report

**Synthesis agent ID:** beb3b143-038d-490e-bf76-bd2d8fc898ce
**Verifier agent ID:** a3848d4f3178d25b7 (round 2; round 1 report in drafts/)

Round: 2 (fresh sample after remediation)

**Date:** 2026-10-03
**Sample size:** 21 of 69 (30%)
**Method:** seeded random draw (seed 20261032), not weighted

## Sampled filenames

t1-burdakov-pmbok-ai-2025.md, t1-pmbok8-pma-vs-pmbok7.md, t1-scrum-guide-2020.md, t2-arnold-maersk-cost-of-delay.md,
t2-gilad-ice-scores.md, t2-manheim-goodhart-variants.md, t2-sleesman-escalation-meta-analysis.md,
t2-yeret-cost-of-delay-intuition-exercise.md, t3-55degrees-littles-law-assumptions.md,
t3-beck-orosz-mckinsey-response.md, t3-scrum-guide-definition-of-done.md, t3-sjoberg-wip-kanban-study.md,
t3-vilasboas-one-person-squad-2026.md, t4-corry-retrospective-antipatterns.md, t4-hn-retrospectives-thread.md,
t4-lehtinen-retrospectives-2017.md, t4-scrum-guide-definition-of-done.md, t4-snow-keil-status-reporting-distortion.md,
t4-tannenbaum-cerasoli-debriefs-meta-analysis.md, t5-liebel-adhd-software-engineers.md,
t5-toli-implementation-intentions-mental-health-meta.md

## Per-card outcomes

- `t1-burdakov-pmbok-ai-2025.md`: verified; both quotes found in PDF text; see note 1
- `t1-pmbok8-pma-vs-pmbok7.md`: verified; 3 quotes found, headings/paragraphs match
- `t1-scrum-guide-2020.md`: verified; 5 quotes found, sections match; see note 2
- `t2-arnold-maersk-cost-of-delay.md`: verified; both quotes found, sections match
- `t2-gilad-ice-scores.md`: verified; both quotes found, sentence/bullet positions match
- `t2-manheim-goodhart-variants.md`: verified; both quotes found (hyphenation only), locations match
- `t2-sleesman-escalation-meta-analysis.md`: verified; 3 quotes found; Methods/Conclusions positions match
- `t2-yeret-cost-of-delay-intuition-exercise.md`: verified; both quotes found, paragraph/sentence match
- `t3-55degrees-littles-law-assumptions.md`: verified; 3 quotes found; see note 3
- `t3-beck-orosz-mckinsey-response.md`: verified; quote found in last intro paragraph, 2nd sentence
- `t3-scrum-guide-definition-of-done.md`: verified; both quotes found; DoD paragraphs 1 and 3 match
- `t3-sjoberg-wip-kanban-study.md`: inaccessible; ACM URL 403; card flagged cached/partial
- `t3-vilasboas-one-person-squad-2026.md`: verified; 3 abstract quotes found, sentence positions match
- `t4-corry-retrospective-antipatterns.md`: verified; both quotes found, sections/paragraphs match
- `t4-hn-retrospectives-thread.md`: verified; both comments found, nesting levels match
- `t4-lehtinen-retrospectives-2017.md`: inaccessible; Springer returns bot challenge; card flagged cached/partial
- `t4-scrum-guide-definition-of-done.md`: verified; both quotes found; Increment p3, DoD p3 match
- `t4-snow-keil-status-reporting-distortion.md`: inaccessible; IEEE/doi page empty to fetch; card cached/partial
- `t4-tannenbaum-cerasoli-debriefs-meta-analysis.md`: verified; 3 quotes found in PDF; sections match
- `t5-liebel-adhd-software-engineers.md`: verified; abstract and HTML 5.1 Strategies quotes found
- `t5-toli-implementation-intentions-mental-health-meta.md`: inaccessible; Wiley 403 bot block; card cached/partial

## Notes

1. Burdakov Quote 1: card says "second sentence of the abstract"; it is the third (within the off-by-one tolerance).
2. Scrum Guide 2020 (t1): "Sprints enable predictability" is paragraph 4 if the "During the Sprint:" lead-in is not
   counted, 5 if it is; within tolerance.
3. 55 Degrees: the "Throughput form" sentence is the 4th (not 3rd) sentence of its paragraph; within tolerance.
4. Maersk: both quotes sit in "Finding the Black Swan"; quote 2 is under its sub-section "The distribution of Value" as
   the card says. Checked against raw HTML (the summarizing fetch tool misreported this).
5. Sjoberg, Lehtinen, Snow-Keil, Toli: the live host was blocked or empty for automated fetch (HTTP 403, bot challenge
   or empty page). Each card carries `Access status: cached/partial`, so per protocol they are inaccessible, not failed.
   No substitute host was used to confirm any quote.
6. Method: quotes were matched against raw HTML (converted to text) or pdftotext output of the card's own URL host;
   smart/straight quotes, hyphenation at line breaks and column interleaving were treated as trivial.

## Aggregate counts

- verified: 17
- failed: 0
- inaccessible: 4

Failure rate = failed / (verified + failed) = 0 / 17 = 0%

Band: `<=5%`

Inaccessible share: 4 of 21 (19%), below the ~30% threshold, so no low-confidence stamp.
