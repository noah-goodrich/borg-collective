# Citation verification report

**Synthesis agent ID:** beb3b143-038d-490e-bf76-bd2d8fc898ce
**Verifier agent ID:** a39d5cbf904c10fbc

**Sample size:** 18 of 59 (30%)
**Method:** seeded random draw (seed 20261031), not weighted

## Sampled files

c1-dejong-2010-clt-open-questions.md, c1-fourcade-2012-checklist-barriers.md,
c1-higdon-2025-distinctiveness-not-dual-coding.md, c1-thomassen-2010-help-or-hurdle.md,
c1-weiser-haynes-2018-ten-years-checklist.md, c2-aan-willcox-feeling-wheel.md, c2-ariely-2026-replication.md,
c2-kalokerinos-2019-differentiate-to-regulate.md, c2-nook-2021-naming-impedes.md, c2-torre-lieberman-2018-review.md,
c3-alfieri-2013-case-comparisons.md, c3-donker-2009-psychoeducation-meta-analysis.md,
c3-gawrilow-adhd-implementation-intentions.md, c3-implementation-intentions-642-tests.md,
c3-nvc-korean-nursing-rct-2025.md, c4-arnsten-stress-prefrontal.md, c4-faraone-2019-emotional-dysregulation.md,
c4-shaw-2014-emotion-dysregulation.md

## Per-card results

| filename | outcome | notes |
|----------|---------|-------|
| c1-dejong-2010-clt-open-questions.md | verified | |
| c1-fourcade-2012-checklist-barriers.md | inaccessible | see note 1 |
| c1-higdon-2025-distinctiveness-not-dual-coding.md | inaccessible | see note 1 |
| c1-thomassen-2010-help-or-hurdle.md | verified | |
| c1-weiser-haynes-2018-ten-years-checklist.md | verified | |
| c2-aan-willcox-feeling-wheel.md | verified | |
| c2-ariely-2026-replication.md | verified | |
| c2-kalokerinos-2019-differentiate-to-regulate.md | inaccessible | see note 1 |
| c2-nook-2021-naming-impedes.md | verified | |
| c2-torre-lieberman-2018-review.md | verified | |
| c3-alfieri-2013-case-comparisons.md | verified | |
| c3-donker-2009-psychoeducation-meta-analysis.md | verified | |
| c3-gawrilow-adhd-implementation-intentions.md | verified | |
| c3-implementation-intentions-642-tests.md | verified | |
| c3-nvc-korean-nursing-rct-2025.md | verified | |
| c4-arnsten-stress-prefrontal.md | verified | |
| c4-faraone-2019-emotional-dysregulation.md | verified | |
| c4-shaw-2014-emotion-dysregulation.md | verified | |

## Notes

1. The card URL is `europepmc.org/article/MED/<pmid>`. It returned HTTP 403 (Cloudflare challenge) to curl and
   WebFetch, so I could not search it. Each card has `Access status: cached/partial`, so the outcome is `inaccessible`.
   As a side check, I searched the same PMIDs' Europe PMC REST records on `ebi.ac.uk`, which is a different host from
   the card URL. Every quote appeared there character-for-character, and the sentence locations matched. That check
   does not change the outcome. It suggests these three cards would pass if the card URL were the REST record, as the
   Faraone and Shaw cards use.
2. For the PDFs (Torre, 642 tests) I used pdftotext. Torre needed non-layout mode because the two-column layout
   interleaves text. Torre quote 2 is on p. 120 under "Further Considerations", sentence 2. 642-tests quotes are on
   PDF p. 9 under the stated sub-heading.
3. All quotes matched after normalizing smart or straight quotes, dashes and whitespace. All location references
   checked were correct or off by no more than one paragraph or sentence.

## Aggregate counts

- verified: 15
- failed: 0
- inaccessible: 3

**Failure rate** = failed / (verified + failed) = 0 / 15 = 0%
**Band:** <=5%

Inaccessible is 3 of 18 (17%), which is under the ~30% threshold, so no low-confidence stamp.
