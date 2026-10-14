# Source: SkillsBench: Benchmarking How Well Agent Skills Work Across Diverse Tasks (arXiv 2602.12670)

**Full citation:** Xiangyi Li et al. (77 authors, incl. Dawn Song). "SkillsBench: Benchmarking How Well Agent Skills Work Across Diverse Tasks." arXiv:2602.12670 v4. Submitted 2026-02-13, revised 2026-06-14.
**URL:** https://arxiv.org/abs/2602.12670
**Date accessed:** 2026-10-13
**Evidence level:** 3 (Large-scale controlled benchmark; arXiv preprint, not peer-reviewed)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 8/10 | large academic team |
| 2 | Evidence Quality | 8/10 | paired no-skill/skill |
| 3 | Currency | 10/10 | 4 months old |
| 4 | Intent | 9/10 | pure inquiry |
| 5 | Bias & Objectivity | 8/10 | limitations stated |
| 6 | Logic & Coherence | 8/10 | sound design |
| 7 | Corroboration | 7/10 | agrees w/ SWE bench |
| 8 | Intellectual Honesty | 8/10 | hedges by domain |
| 9 | Specificity | 9/10 | 87 tasks, 18 configs |
| 10 | Relevance | 5/10 | tests skills, not Pocock |

Justifications (one line per dimension, same order):

1. Authority: A 77-author academic and industry team with verifiable affiliations.
2. Evidence Quality: Paired no-skill versus curated-skill runs across 87 tasks, 8 domains, 18 model-harness configurations with deterministic verifiers.
3. Currency: Revised 2026-06-14, within five months.
4. Intent: Academic benchmark intended as a public measuring stick.
5. Bias & Objectivity: Reports gains varying by configuration (+4.1 to +25.7 pp) rather than one headline.
6. Logic & Coherence: Design and conclusion are consistent.
7. Corroboration: Direction partly matches SWE-Skills-Bench (limited SWE gains) and the Skill-induced-failures study.
8. Intellectual Honesty: Stresses that focused skills beat exhaustive bundles, a qualified finding.
9. Specificity: Gives pass rates, task counts and model-harness counts.
10. Relevance: Does not test Pocock's skills; it measures skills in general, so applicability is by analogy.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Curated skills raised average pass rate from 33.9% to 50.5% (+16.6 pp) across 18 model-harness configurations, so skills can help.
- Focused skills of at most three modules outperform larger or exhaustive bundles, which bears on the "install 37 skills" pattern.
- Smaller models with skills can match larger models without them.
- It does not evaluate Pocock's skills or any specific community pack; a "does grill-me improve output" test does not yet exist in the corpus.

## Verified Quote(s)

**Location reference:** arXiv abstract page, Abstract paragraph, sentences 4 and 5.

> Curated Skills raise the average pass rate from 33.9% to 50.5% (+16.6 percentage points; 25.5% normalized gain), with configuration-level gains ranging from +4.1 to +25.7 pp.

> Focused Skills with at most three modules outperform larger or exhaustive bundles, and smaller models with Skills can match larger models without them.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Keep band; Supporting rather than Core because it does not test Pocock's skills. It is the academic anchor for "skills help when curated and focused".

**Redundancy check:** Complements SWE-Skills-Bench (which finds smaller SWE gains) and Skill-induced-failures (which explains regressions).

**Perspective category:** Academic
