# Citation verification report

**Synthesis agent ID:** beb3b143-038d-490e-bf76-bd2d8fc898ce

**Verifier agent ID:** af424dfeb01de4ddb

Round: v2 (98-card set after the 2026-10-04 re-scope; v1 59-card report archived in drafts/)

Sample `30 of 98 (30%)`, method `seeded random draw (seed 20261004), not weighted`.

Sampled filenames: c1-higdon-2025-distinctiveness-not-dual-coding.md, c1-nngroup-recognition-vs-recall.md, c1-wang-voss-2021-pictograph-review.md, c2-brownstone-2024-ifs-problematic-popularity.md, c2-ford-parnin-2015-frustration-categories.md, c2-kalokerinos-2019-differentiate-to-regulate.md, c2-lieberman-2007-amygdala.md, c2-nook-2021-naming-impedes.md, c2-shadick-2013-ifs-ra-rct.md, c2-shimmer-2024-naming-feelings-adhd.md, c2-wahba-2026-affect-labeling-meta-zenodo.md, c3-brighter-coach-action-planning-adhd.md, c3-corbett-2015-yerkes-dodson-folklore.md, c3-corrigan-2011-window-of-tolerance.md, c3-gottman-levenson-2000-timing-of-divorce.md, c3-nvc-korean-nursing-rct-2025.md, c4-chop-ef-adhd-handout.md, c4-gani-alert-fatigue-primary-care.md, c4-nahum-shani-jitai-framework.md, s1-bakdash-2021-sa-validity-meta.md, s1-hawksley-2026-timeframe-blank-is-healthy.md, s2-parnin-deline-2010-resumption-cues.md, s2-starmer-2022-ipass-32-hospitals.md, s3-glockner-2016-hungry-judge-revisited.md, s3-hagger-2016-ego-depletion-rrr.md, s3-maier-2022-no-evidence-nudging.md, s3-maier-2025-decision-fatigue-healthcare-review.md, s3-morkes-nielsen-1997-concise-scannable-objective.md, s3-scheibehenne-2010-choice-overload-meta.md, s3-willemsen-2016-diverse-small-sets.md

| filename | outcome | notes |
|---|---|---|
| c1-higdon-2025-distinctiveness-not-dual-coding.md | inaccessible | see note 1 |
| c1-nngroup-recognition-vs-recall.md | verified | see note 2 |
| c1-wang-voss-2021-pictograph-review.md | inaccessible | see note 1 |
| c2-brownstone-2024-ifs-problematic-popularity.md | verified | all quotes found; location consistent |
| c2-ford-parnin-2015-frustration-categories.md | verified | see note 3 |
| c2-kalokerinos-2019-differentiate-to-regulate.md | inaccessible | see note 1 |
| c2-lieberman-2007-amygdala.md | verified | all quotes found; location consistent |
| c2-nook-2021-naming-impedes.md | verified | all quotes found; location consistent |
| c2-shadick-2013-ifs-ra-rct.md | verified | all quotes found; location consistent |
| c2-shimmer-2024-naming-feelings-adhd.md | verified | all quotes found; location consistent |
| c2-wahba-2026-affect-labeling-meta-zenodo.md | verified | see note 4 |
| c3-brighter-coach-action-planning-adhd.md | verified | all quotes found; location consistent |
| c3-corbett-2015-yerkes-dodson-folklore.md | verified | see note 5 |
| c3-corrigan-2011-window-of-tolerance.md | verified | all quotes found; location consistent |
| c3-gottman-levenson-2000-timing-of-divorce.md | verified | see note 3 |
| c3-nvc-korean-nursing-rct-2025.md | verified | all quotes found; location consistent |
| c4-chop-ef-adhd-handout.md | verified | see note 6 |
| c4-gani-alert-fatigue-primary-care.md | verified | all quotes found; location consistent |
| c4-nahum-shani-jitai-framework.md | verified | all quotes found; location consistent |
| s1-bakdash-2021-sa-validity-meta.md | verified | all quotes found; location consistent |
| s1-hawksley-2026-timeframe-blank-is-healthy.md | verified | all quotes found; location consistent |
| s2-parnin-deline-2010-resumption-cues.md | verified | all quotes found; location consistent |
| s2-starmer-2022-ipass-32-hospitals.md | verified | all quotes found; location consistent |
| s3-glockner-2016-hungry-judge-revisited.md | verified | see note 3 |
| s3-hagger-2016-ego-depletion-rrr.md | verified | all quotes found; location consistent |
| s3-maier-2022-no-evidence-nudging.md | verified | all quotes found; location consistent |
| s3-maier-2025-decision-fatigue-healthcare-review.md | verified | all quotes found; location consistent |
| s3-morkes-nielsen-1997-concise-scannable-objective.md | verified | all quotes found; location consistent |
| s3-scheibehenne-2010-choice-overload-meta.md | verified | all quotes found; location consistent |
| s3-willemsen-2016-diverse-small-sets.md | verified | all quotes found; location consistent |

Notes:

1. The europepmc.org/article page returns HTTP 403 to both curl and WebFetch, and the card is flagged Access status: cached/partial (abstract was read via the Europe PMC REST API, which is not the card URL), so the outcome is inaccessible.
2. Quote 2 appears on the live page with whitespace before the full stop ("memories . Interfaces"), which is a trivial whitespace/markup difference; both quotes match and are in the heuristic 6 section.
3. PDF source; the layout-mode text extraction interleaves the two columns, so the check was repeated with reading-order extraction (pdftotext without -layout) and all quotes matched. Gottman page placement and Glockner Critical Evaluation paragraph both consistent.
4. doi.org/zenodo is blocked to curl (HTTP 403, Cloudflare); WebFetch via the zenodo.org record confirmed both exact strings in the stated 'Headline result' and 'Pre-registration status' sections. Weaker evidence than a raw-text grep because the WebFetch layer is a model summariser, but it confirmed both strings character-for-character.
5. Emerald page blocks curl (403) but was reachable via WebFetch, which returned the Findings field in chunks that concatenate exactly to the quoted sentence. Same summariser caveat as note 4.
6. curl returned 403; the PDF was obtained through WebFetch's saved binary copy and extracted with pdftotext; both quotes match; working-memory definition sits in the third bullet as stated.

## Aggregate

- verified: 27
- failed: 0
- inaccessible: 3 (c1-higdon, c1-wang-voss, c2-kalokerinos; all europepmc.org/article pages that return 403)
- Total: 30

Failure rate = failed / (verified + failed) = 0 / 27 = 0%.

Band: `<=5%`

Inaccessible share is 10% of the sample (3 of 30), below the ~30% threshold, so no low-confidence stamp is applied.
