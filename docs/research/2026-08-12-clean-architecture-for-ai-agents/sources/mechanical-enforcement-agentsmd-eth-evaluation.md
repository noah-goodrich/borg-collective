# Source: Evaluating AGENTS.md — Are Repository-Level Context Files Helpful for Coding Agents?

**Full citation:** Gloaguen, Thibaud; Mündler, Niels; Müller, Mark; Raychev, Veselin; Vechev, Martin.
"Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?" arXiv:2602.11988
(v1 Feb 12, 2026; v2 June 23, 2026). ICLR 2026 Workshop on Memory for LLM-Based Agentic Systems.
**URL:** https://arxiv.org/abs/2602.11988
**Date accessed:** 2026-08-12
**Evidence level:** 3 (Large-scale Observational/Experimental — SWE-bench tasks plus a novel 138-instance,
5,694-PR dataset; workshop-reviewed arXiv preprint, lighter review bar than a peer-reviewed main-track paper)
**Research topic area:** Mechanical enforcement vs. documented convention for AI agents

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 9/10 | ETH Zurich's SRI Lab (Martin Vechev's group), a leading academic group in AI/software security and reliability research — high institutional authority. |
| 2 | Evidence Quality | 9/10 | Two complementary experimental settings (SWE-bench Lite with LLM-generated context files; a novel 138-repository-instance dataset drawn from 5,694 real PRs with developer-committed context files), tested across multiple LLMs and agents with proper controlled conditions (no file / LLM-generated file / developer file). |
| 3 | Currency | 9/10 | Published Feb 2026, revised June 2026; tests contemporary agents and a live, actively-debated practice. |
| 4 | Intent | 9/10 | Academic research intent, accepted to an ICLR workshop; no commercial stake in the AGENTS.md convention either way. |
| 5 | Bias & Objectivity | 9/10 | Publishes a finding that runs directly against vendor guidance ("strongly encouraged by agent developers") to write context files — a result with no incentive alignment toward the authors' own tooling. |
| 6 | Logic & Coherence | 9/10 | Clean three-condition experimental design isolates the causal question (does the file itself help) rather than conflating it with confounds like task difficulty. |
| 7 | Corroboration | 7/10 | Corroborates and is corroborated by McMillan's factorial study (no detectable benefit from file-structure/context-file variables); partially in tension with the GitHub agents.md blog post's confident structural-best-practices claims. |
| 8 | Intellectual Honesty | 9/10 | Draws a carefully bounded conclusion — instructions ARE followed, but repository overviews specifically are not helpful, and any performance-improvement claim should be "rigorously evaluated before deployment" rather than assumed. |
| 9 | Specificity | 9/10 | Quantifies the cost/benefit precisely: task success rate does not generally improve, while inference cost rises "over 20% on average." |
| 10 | Relevance | 9/10 | Directly tests the documented-convention side of the track's core dichotomy — whether writing the rules down (without mechanical enforcement) actually changes agent behavior or outcomes, a slightly different but tightly related question to raw rule-compliance. |

**Score band:** keep

## Bias Guard Check
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [x] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(Disagreement noted: the working assumption entering this track was that better-written documentation
straightforwardly helps agents. This paper's finding that context files are net-neutral-to-negative on task
success is the least comfortable finding of the six kept sources for a "just write it down clearly" thesis,
so credibility/coherence were checked especially carefully rather than discounted for being inconvenient.)

## Key Findings
- Across both SWE-bench tasks (with LLM-generated context files) and a novel 138-instance dataset of
  repositories with real developer-committed AGENTS.md files, providing a context file "does not generally
  improve task success rates, while increasing inference cost by over 20% on average" — a result that held
  across different LLMs, different coding agents, and both LLM-generated and developer-written files.
- Critically, the paper distinguishes WHY: "instructions in the context files are well followed by coding
  agents" — so the failure is not a compliance problem — but "repository overviews, although popular and
  recommended by model providers, are not helpful," meaning the specific popular practice of writing
  narrative repo-architecture summaries in these files is the part that doesn't pay off.
- This narrows what documented conventions are actually good for: the authors conclude context files remain
  useful "for specifying non-standard coding practices" (i.e., concrete, checkable rules) — not for
  explaining architecture in prose, which agents will follow if given but does not move outcomes.
- This is an important complement to RepoComplianceBench's finding that restraint/boundary-type rules need
  enforcement: here, even purely descriptive/architectural documentation that agents DO read and comply with
  fails to produce better behavior, reinforcing that documentation's value ceiling is lower than commonly
  assumed even in the best case (rules are read and followed).

## Verified Quote(s)

**Location reference:** Abstract, arXiv:2602.11988v1/v2.

> "Surprisingly, we find that providing context files does not generally improve task success rates, while
> increasing inference cost by over 20% on average."

> "we find that while instructions in the context files are well followed by coding agents, repository
> overviews, although popular and recommended by model providers, are not helpful."

**Access status:** live

## Inclusion Decision
**Decision:** Core
**Rationale:** This is the closest thing to a genuine contrarian/counter-narrative voice this track found —
not arguing that mechanical enforcement is unnecessary, but that the presumed alternative (well-written
documentation) has a much lower ceiling than assumed, even in the case where the agent reads and follows it.
That directly strengthens the case for enforcement as the more reliable lever, from the opposite direction of
RepoComplianceBench.
**Redundancy check:** Distinct question from RepoComplianceBench (task-outcome value of context files vs.
raw rule-compliance rates) and from McMillan (file structure vs. whether the file helps at all); together the
three academic sources triangulate the documentation side of the track from three independent angles.
**Perspective category:** Contrarian

---
