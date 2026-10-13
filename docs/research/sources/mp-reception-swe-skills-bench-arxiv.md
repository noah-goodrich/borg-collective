# Source: SWE-Skills-Bench: Do Agent Skills Actually Help in Real-World Software Engineering? (arXiv 2603.15401)

**Full citation:** SWE-Skills-Bench authors. "SWE-Skills-Bench: Do Agent Skills Actually Help in Real-World Software Engineering?" arXiv:2603.15401. Submitted 2026-03-16.
**URL:** https://arxiv.org/abs/2603.15401
**Date accessed:** 2026-10-13
**Evidence level:** 3 (Large-scale controlled benchmark; arXiv preprint, not peer-reviewed)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 7/10 | academic preprint |
| 2 | Evidence Quality | 8/10 | ~565 paired tasks |
| 3 | Currency | 10/10 | 7 months old |
| 4 | Intent | 9/10 | pure inquiry |
| 5 | Bias & Objectivity | 8/10 | states mixed results |
| 6 | Logic & Coherence | 8/10 | sound |
| 7 | Corroboration | 7/10 | Every article cites it |
| 8 | Intellectual Honesty | 8/10 | qualifies domain fit |
| 9 | Specificity | 9/10 | pass-rate numbers |
| 10 | Relevance | 6/10 | SWE skills, not Pocock |

Justifications (one line per dimension, same order):

1. Authority: Academic preprint; author list not examined here, so scored a notch below SkillsBench.
2. Evidence Quality: About 565 task instances on pinned GitHub repos with execution-based acceptance tests, run with and without each skill.
3. Currency: Submitted 2026-03-16, so models tested may be older than the Fable/Opus 5 generation now in use.
4. Intent: Benchmark intended to isolate marginal utility of skills.
5. Bias & Objectivity: Reports both the many null results and the few large wins.
6. Logic & Coherence: Conclusion ("narrow intervention") follows from the pass-rate pattern.
7. Corroboration: Every's newsletter independently reports the same 49/39/3/7 figures.
8. Intellectual Honesty: Qualifies that utility depends on domain fit, abstraction level and context.
9. Specificity: Gives 39 of 49 no gain, +1.2% average, 451% token overhead, 7 specialized gains, 3 degradations.
10. Relevance: Skills are public SWE skills, not Pocock's; relevant by analogy to TDD/debugging-type skills.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- 39 of 49 public SWE skills yield zero pass-rate improvement; average gain only +1.2%.
- Token overhead ranged from modest savings to +451% with unchanged pass rates.
- Only seven specialized skills gave meaningful gains (up to +30%), and three degraded performance (up to -10%) because version-mismatched guidance conflicted with project context.
- Implication for Pocock-style generic process skills (TDD, debugging): the measured SWE evidence is that generic skills mostly do not change pass rate, which is a falsification risk; no study tested his pack directly.

## Verified Quote(s)

**Location reference:** arXiv abstract page, Abstract paragraph, sentences 4 and 6.

> Our results show that skill injection benefits are far more limited than rapid adoption suggests: 39 of 49 skills yield zero pass-rate improvement, and the average gain is only +1.2%.

> Only seven specialized skills produce meaningful gains (up to +30%), while three degrade performance (up to -10%) due to version-mismatched guidance conflicting with project context.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Keep band. Supporting because the skills tested are not Pocock's; it is the falsification anchor ("skills often do nothing") for the generic-process-skill pattern.

**Redundancy check:** Primary source for figures that the Every card reports secondhand; Skill-induced-failures cites the same benchmark.

**Perspective category:** Academic
