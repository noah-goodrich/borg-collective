# Source: GitHub REST API metadata for mattpocock/skills and mattpocock/sandcastle

**Full citation:** GitHub, Inc. REST API "GET /repos/mattpocock/skills", "/releases", "/repos/mattpocock/sandcastle". Queried live 2026-10-13.
**URL:** https://api.github.com/repos/mattpocock/skills
**Date accessed:** 2026-10-13
**Evidence level:** 3 (large-scale platform observational data, machine-generated)
**Research topic area:** WHAT IT IS (primary sources): mattpocock/skills, Sandcastle, AI Hero, Matt's stated philosophy

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | GitHub is the system of record for its own repository counters and release timestamps. |
| 2 | Evidence Quality | 8/10 | Machine-generated counters and ISO timestamps; no interpretation involved. |
| 3 | Currency | 10/10 | Queried live on the access date. |
| 4 | Intent | 8/10 | A neutral platform API with no promotional purpose. |
| 5 | Bias & Objectivity | 9/10 | No editorial slant; star counts can be inflated by trending or botting but the API cannot tell. |
| 6 | Logic & Coherence | 8/10 | Fields are internally consistent (created_at, pushed_at, commit count 545 via pagination). |
| 7 | Corroboration | 7/10 | Star trajectory corroborated by third-party snapshots (about 58.5k in May, 239k in August per a guide) which differ only by date. |
| 8 | Intellectual Honesty | 7/10 | Does not editorialise, but also cannot disclose data quality problems. |
| 9 | Specificity | 10/10 | Exact numbers: 289,479 stars, 24,301 forks, MIT, created 2026-02-03; releases v1.0.0 (2026-06-17) through v1.3.1 (2026-10-04). |
| 10 | Relevance | 9/10 | Settles the star, licence and release-cadence questions and exposes inconsistent third-party figures. |

**Score band:** keep

(Intermediate weighted average about 8.3; the disposition is the band word.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Live star count was 289,479 with 24,301 forks and MIT licence on 2026-10-13, so the 'inconsistent' public figures (58.5k in May, 160k in July, 230k+ in August, 239k in an August guide) are consistent snapshots of one rising curve.
- The repo's first commit and created_at are both 2026-02-03; the often-repeated 'published in late April 2026' describes the public viral moment, not the creation date.
- Releases API shows the tagged versions: v1.0.0 and v1.0.1 on 2026-06-17, v1.1.0 on 2026-07-08, v1.2.0/1.2.2/1.2.3 on 2026-08-05/06, v1.3.0 and v1.3.1 on 2026-10-04.
- Contribution is overwhelmingly single-author: the contributors API lists the owner (499 contributions) and only three other contributors (claude, a bot, and one account).
- Sandcastle is a separate, much smaller project: 8,418 stars, MIT, created 2026-03-17, npm latest 0.12.0 (published 2026-06-29).

## Verified Quote(s)

**Location reference:** Quote 1: Repo object JSON for mattpocock/skills, field stargazers_count; Quote 2: Repo object JSON for mattpocock/skills, field created_at; Quote 3: Releases JSON, the entry whose tag_name is v1.1.0; Quote 4: Repo object JSON for mattpocock/sandcastle (same host, path /repos/mattpocock/sandcastle), field stargazers_count

> "stargazers_count": 289479,

> "created_at": "2026-02-03T11:15:53Z",

> "published_at": "2026-07-08T13:20:57Z"

> "stargazers_count": 8418,

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Neutral primary data that resolves the star-count and date inconsistencies reported in the novelty probe.

**Redundancy check:** Unique for counters and release dates; the changelog gives the content of each release.

**Perspective category:** Institutional
