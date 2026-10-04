# Citation Verification Report

**Synthesis agent ID:** beb3b143-038d-490e-bf76-bd2d8fc898ce
**Verifier agent ID:** a8abd85f974622fff (round 1; superseded — failure rate >10%, remediated per path 1, re-sampled)

**Sample size:** 21 of 69 (30%)
**Selection method:** seeded random draw (seed 20261003), not weighted

**Sampled filenames:** t1-burdakov-pmbok-ai-2025.md, t1-eveleens-verhoef-chaos-2010.md, t1-hn-solo-devs-plan-2019.md,
t1-pmbok8-pma-vs-pmbok7.md, t1-pmi-pmbok7-facts-faq.md, t2-leaddev-when-to-kill-software-project.md,
t2-manheim-goodhart-variants.md, t2-yeret-cost-of-delay-intuition-exercise.md, t3-dora-trunk-based-development.md,
t3-hn-ask-solo-developer-organize-work.md, t3-metr-rct-2025.md, t3-space-framework-forsgren-2021.md,
t3-vilasboas-one-person-squad-2026.md, t4-bevan-hood-targets-gaming.md, t4-corry-retrospective-antipatterns.md,
t4-maric-postmortems-that-change-nothing.md, t4-scrum-guide-definition-of-done.md, t5-liebel-adhd-software-engineers.md,
t5-rubinstein-meyer-evans-task-switching.md, t5-scienceworks-external-systems-adhd-REJECTED.md, t5-work-map-adhd-rct.md

Method: each card URL fetched live (curl), HTML/PDF converted to text, quotes matched after trivial normalisation
(smart quotes, whitespace, dashes), then location references checked against page structure.

## Per-card results

| filename | outcome | notes |
|----------|---------|-------|
| t1-burdakov-pmbok-ai-2025.md | verified | Both quotes verbatim in the arXiv PDF (abstract; conclusions). |
| t1-eveleens-verhoef-chaos-2010.md | verified | Both quotes verbatim on p.30 intro. |
| t1-hn-solo-devs-plan-2019.md | verified | All 3 quotes verbatim; commenters as stated. |
| t1-pmbok8-pma-vs-pmbok7.md | verified | All 3 quotes verbatim under the stated headings. |
| t1-pmi-pmbok7-facts-faq.md | verified | Both quotes verbatim; numbered facts 3 and 4. |
| t2-leaddev-when-to-kill-software-project.md | failed | Quotes verbatim, but quote 2 ("Our kill switch...") is the 5th paragraph under "Set kill criteria upfront and timebox it", not paragraph 2 as the card states (off by 3). |
| t2-manheim-goodhart-variants.md | verified | Both quotes verbatim in the PDF (abstract; intro enumeration). |
| t2-yeret-cost-of-delay-intuition-exercise.md | verified | Both quotes verbatim in the stated section. |
| t3-dora-trunk-based-development.md | verified | Quote verbatim on the capability page. |
| t3-hn-ask-solo-developer-organize-work.md | verified | All 3 quotes verbatim; OP and davidclark22 as stated. |
| t3-metr-rct-2025.md | verified | All 4 quotes verbatim; banner after BibTeX as stated. |
| t3-space-framework-forsgren-2021.md | inaccessible | Live URL returned HTTP 403 (bot block); card has Access status cached/partial and an Access note (user-supplied copy). |
| t3-vilasboas-one-person-squad-2026.md | verified | All 3 quotes verbatim in the abstract. |
| t4-bevan-hood-targets-gaming.md | verified | Quote verbatim in the LSE abstract. |
| t4-corry-retrospective-antipatterns.md | verified | Both quotes verbatim in the stated sections. |
| t4-maric-postmortems-that-change-nothing.md | failed | Quotes verbatim, but quote 1 is the 2nd paragraph of "The gap between writing and doing", not the 4th as the card states (off by 2). |
| t4-scrum-guide-definition-of-done.md | verified | Both quotes verbatim. Note: quote 1 sits in the last sentence of the Increment intro, one paragraph above the DoD subheading (adjacent; tolerated). |
| t5-liebel-adhd-software-engineers.md | verified | Quote 1 on the abs page; quote 2 not on abs but on arxiv.org/html/2312.05029 (same host, as the card states). |
| t5-rubinstein-meyer-evans-task-switching.md | inaccessible | doi.org returned an Incapsula bot-block page; card has Access status cached/partial (abstract via Europe PMC). |
| t5-scienceworks-external-systems-adhd-REJECTED.md | failed | Quote verbatim, but it is in the closing FAQ ("Aren't external systems just crutches?"), AFTER the Barkley paragraphs; the card says it is the paragraph preceding the Barkley model paragraph. Location wrong. |
| t5-work-map-adhd-rct.md | verified | Both quotes verbatim in the PMC abstract (Results/Conclusions). |

## Aggregate counts

- verified: 16
- failed: 3
- inaccessible: 2

**Failure rate** = failed / (verified + failed) = 3 / 19 = 15.8%

**Band:** >10%

(Inaccessible 2 of 21 = 9.5%, under the ~30% threshold, so no low-confidence stamp.)

All three failures are location-reference errors; no quote was paraphrased, misattributed or absent.
