# Source: Agent Skills Can Be Harmful: An Empirical Study of Skill-Induced Failures (arXiv 2608.11888)

**Full citation:** Gen Dong, Yanjie Gao, Liqun Li, Tianyin Xu, Yu Hua, Fan Yang. "Agent Skills Can Be Harmful: An Empirical Study of Skill-Induced Failures in LLM Agents." arXiv:2608.11888 v1. Submitted 2026-08-12.
**URL:** https://arxiv.org/abs/2608.11888
**Date accessed:** 2026-10-13
**Evidence level:** 3 (Large-scale analysis of benchmark runs; arXiv preprint, not peer-reviewed)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 7/10 | academic preprint |
| 2 | Evidence Quality | 8/10 | 307 attributed failures |
| 3 | Currency | 10/10 | 2 months old |
| 4 | Intent | 9/10 | pure inquiry |
| 5 | Bias & Objectivity | 8/10 | balanced framing |
| 6 | Logic & Coherence | 8/10 | sound |
| 7 | Corroboration | 6/10 | prior work agrees |
| 8 | Intellectual Honesty | 8/10 | proposes future work |
| 9 | Specificity | 9/10 | counts by category |
| 10 | Relevance | 6/10 | skills in general |

Justifications (one line per dimension, same order):

1. Authority: Six academic authors including systems researchers; credible but newly posted.
2. Evidence Quality: Differential analysis attributing 307 failures (125 functional, 182 efficiency) to specific loaded skills on two benchmarks.
3. Currency: Submitted 2026-08-12, the freshest empirical item in the set.
4. Intent: Academic inquiry with a tool release (SkillTriage).
5. Bias & Objectivity: Opens by acknowledging mixed prior results, not a one-sided case.
6. Logic & Coherence: Taxonomy follows from the failure attribution method.
7. Corroboration: Consistent with SWE-Skills-Bench and Every's reporting; single version, no replication yet.
8. Intellectual Honesty: Lists its contributions as taxonomy and proposed research topics rather than proof of causes.
9. Specificity: Quantifies 67 excessive-verification and 30 heavy-pipeline cases.
10. Relevance: Not about Pocock, but directly about process-heavy skills that "turn validation checklists into mandatory work".

**Score band:** keep

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

I (and the borg project) lean toward measurement-first skepticism of process skills, so dims 5, 6 and 8 were scored harder.

## Key Findings

- A seemingly relevant skill is a bigger failure source than an irrelevant one: skills often cause the agent to implement or omit required elements incorrectly.
- Efficiency regressions are not explained by prompt length alone.
- The largest "Excessive Procedure" sources are excessive verification (67 cases) and heavy implementation pipelines (30 cases).
- Skills "often turn validation checklists and construction recipes into mandatory work" - directly relevant to Pocock's /tdd, /code-review and /implement-style process skills, though not tested on his repo.

## Verified Quote(s)

**Location reference:** arXiv abstract page, Abstract paragraph, findings (1) and final sentence of finding (3).

> Skill induced functional failures are rarely caused by obviously irrelevant skills; instead, seemingly relevant skills often make the agent incorrectly implement or omit task-required implementation elements.

> This shows that skills often turn validation checklists and construction recipes into mandatory work.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Keep band; Supporting because it is general, but it is the best empirical falsification evidence that process skills can backfire.

**Redundancy check:** Adds the mechanism (mandatory work) beyond the pass-rate result in SWE-Skills-Bench.

**Perspective category:** Academic
