# Source: Snowflake-Labs/cortex-code-skills (community skills catalog)

**Full citation:** Snowflake-Labs. "Snowflake CoCo Skills" (README). GitHub, created 2026-01-20, pushed 2026-10-13, about 41 stars at access. https://github.com/Snowflake-Labs/cortex-code-skills
**URL:** https://github.com/Snowflake-Labs/cortex-code-skills
**Date accessed:** 2026-10-13
**Evidence level:** 5 (vendor-lab practitioner artifact)
**Research topic area:** How Cortex-native skills are distributed and what domain they cover

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Snowflake's Labs organization; contributions from employees, partners, and community. |
| 2 | Evidence Quality | 6/10 | A README and catalog; quality of individual skills not tested here. |
| 3 | Currency | 10/10 | Pushed on the day of access. |
| 4 | Intent | 7/10 | Ecosystem building. |
| 5 | Bias & Objectivity | 6/10 | Promotional but includes a disclaimer. |
| 6 | Logic & Coherence | 8/10 | Organized catalog. |
| 7 | Corroboration | 8/10 | Matches Snowflake docs on the install flow and `$skill` invocation. |
| 8 | Intellectual Honesty | 8/10 | Disclaimer says Snowflake cannot guarantee correctness or security. |
| 9 | Specificity | 8/10 | Concrete install and invocation commands. |
| 10 | Relevance | 8/10 | Shows the Cortex skill ecosystem is Snowflake-domain (semantic views, Snowpipe, PrivateLink), not process or PM skills. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Cortex ships with 50+ bundled skills and extends via community Agent Skills; this repo uses the agentskills.io format.
- A skill repo installs conversationally ("Install the skills from <url>") or via `/skill add`; updates via "Sync my skills".
- Catalog categories are Snowflake documentation, semantic modeling, data engineering and integration; there are no software-process skills like grilling, TDD, or ticket decomposition in the catalog excerpt reviewed.
- Most skills need an active Snowflake connection.

## Verified Quote(s)

**Location reference:** README opening paragraph and "Install these skills" section.

> Each skill is a folder containing a `SKILL.md` that teaches CoCo a workflow, coding standard, or domain-specific best practice.

> Install the skills from https://github.com/Snowflake-Labs/cortex-code-skills

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Documents the native skill ecosystem and install UX that a ported Matt skill set would join.

**Redundancy check:** Distinct from bundled-skills docs; shows community contributions.

**Perspective category:** Practitioner
