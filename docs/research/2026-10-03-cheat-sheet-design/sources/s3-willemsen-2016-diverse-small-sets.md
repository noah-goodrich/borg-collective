# Source: Willemsen et al. 2016 - latent feature diversification, choice difficulty and satisfaction

**Full citation:** Willemsen, M. C., Graus, M. P., & Knijnenburg, B. P. (2016). "Understanding the role of latent feature diversification on choice difficulty and satisfaction." User Modeling and User-Adapted Interaction, 26(4), 347-389. Abstract snapshot from OpenAlex.
**URL:** https://api.openalex.org/works/doi:10.1007/s11257-016-9178-6
**Date accessed:** 2026-10-04
Card revised: 2026-10-04 (location audit before verification)
**Evidence level:** 2 (online user experiments)
**Research topic area:** S3 amount and layering (ranked list vs small set)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | Recommender-systems HCI group at TU Eindhoven / Clemson; peer-reviewed in a leading UMUAI journal. |
| 2 | Evidence Quality | 7/10 | Two online experiments (Study 1a, 1b, Study 2) with movie recommender and structural equation modelling; sample size not in abstract. |
| 3 | Currency | 5/10 | 2016; domain-specific. |
| 4 | Intent | 9/10 | Academic inquiry. |
| 5 | Bias & Objectivity | 7/10 | Authors flag "at least for the movie domain". |
| 6 | Logic & Coherence | 8/10 | SEM conclusions follow. |
| 7 | Corroboration | 5/10 | Consistent with Chernev 2015 (set complexity); no independent replication found. |
| 8 | Intellectual Honesty | 8/10 | Scoped to the movie domain. |
| 9 | Specificity | 7/10 | Study design clear; numbers not in abstract. |
| 10 | Relevance | 8/10 | Directly compares small diverse sets against Top-N lists. |

**Score band:** keep

(Intermediate weighted average 7.1; the band is the disposition.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Diversifying a recommendation set raises perceived diversity and attractiveness while reducing perceived choice difficulty.
- Small diverse sets were as satisfying as traditional Top-N recommendation lists and less effortful to choose from.
- The authors suggest diverse small sets may be the best thing to offer a recommender user (movie domain).
- Design implication: answers "ranked list or one move" only partially - evidence favours a SMALL set, not a single item; no source tested exactly one.

## Verified Quote(s)

**Location reference:** Abstract, sentence 9 of 10 (the abstract is unlabelled; sentence 9 begins "Study 2 extends
these results"). Counting rule: the abstract text is split at a terminal period or question mark followed by a capital
letter (decimals, "vs.", "i.e." and "e.g." do not split). The abstract is reconstructed from the record's
`abstract_inverted_index` by ordering words by position. Snapshot:
drafts/adapter/snapshots/s3q1-01-understanding-the-role-of-latent-feature-diversi.txt
(Snapshot not committed; re-derive from the card URL.)

> Study 2 extends these results by testing our diversification algorithm against traditional Top-N recommendations, and finds that diverse, small item sets are just as satisfying and less effortful to choose from than Top-N recommendations.

**Access status:** cached/partial Card URL changed 2026-10-04 from the DOI landing page (publisher host blocks or does not serve the abstract to automated fetch) to the OpenAlex API record (Europe PMC and Crossref hold no abstract for this DOI), on which the quotes were re-verified.

## Inclusion Decision

**Decision:** Core
**Rationale:** Best direct evidence found on the small-set-vs-ranked-list question. Abstract-only (Springer paywalled); movie domain only.

**Redundancy check:** Only source in the set on set size in a recommender context.

**Perspective category:** Academic
