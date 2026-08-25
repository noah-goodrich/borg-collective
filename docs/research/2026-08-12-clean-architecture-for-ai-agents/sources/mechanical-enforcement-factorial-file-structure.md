# Source: Instruction Adherence in Coding Agent Configuration Files — A Factorial Study

**Full citation:** McMillan, Damon. "Instruction Adherence in Coding Agent Configuration Files: A Factorial
Study of Four File-Structure Variables." arXiv:2605.10039. May 11, 2026.
**URL:** https://arxiv.org/pdf/2605.10039
**Date accessed:** 2026-08-12
**Evidence level:** 3 (Large-scale Observational — factorial design across 1,650 Claude Code CLI sessions;
arXiv preprint, single independent author, not peer-reviewed)
**Research topic area:** Mechanical enforcement vs. documented convention for AI agents

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 5/10 | Single author (Damon McMillan) with no clearly stated institutional affiliation in the accessible metadata — lower authority than an affiliated academic study, though the methodology itself is rigorous. |
| 2 | Evidence Quality | 8/10 | 1,650 real Claude Code CLI sessions across four TypeScript codebases and five coding tasks, cross-model validated (Sonnet 4.6 primary, Opus cross-check), with correction for multiple testing — unusually rigorous for an independently authored study. |
| 3 | Currency | 9/10 | Submitted May 2026, tests current-generation Claude models; directly relevant to present-day agent behavior. |
| 4 | Intent | 8/10 | Genuine empirical research question with no visible commercial angle; publishes a null result rather than a marketable positive claim. |
| 5 | Bias & Objectivity | 9/10 | Reports that file-structure variables (headers, lists, code fences) had "no detectable effects after correction for multiple testing" — a result that undercuts a popular practitioner claim rather than confirming it, which argues against motivated reasoning. |
| 6 | Logic & Coherence | 9/10 | Proper factorial design with statistical correction; the within-session decay finding (odds ratio per generated function) is a clean, well-specified effect. |
| 7 | Corroboration | 6/10 | Its null finding on file structure is corroborated by the ETH Zurich AGENTS.md study's finding that "repository overviews... are not helpful"; the within-session compliance-decay finding is novel among this track's kept sources and not independently replicated here. |
| 8 | Intellectual Honesty | 9/10 | Reports a null main result plainly instead of reframing it as a positive finding — a strong honesty signal, especially for an independently published study with no institutional review process forcing that candor. |
| 9 | Specificity | 9/10 | Quantified effect size: "each additional function the agent generates is associated with approximately 5.6% lower odds of compliance per step." |
| 10 | Relevance | 10/10 | Directly tests whether HOW documented conventions are written (structure vs. prose) changes adherence — the exact granularity question this track was asked to chase. |

**Score band:** keep

## Bias Guard Check
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [x] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(Disagreement noted: going in, the expectation from other practitioner sources in this track — e.g. the
GitHub agents.md piece — was that structure/formatting meaningfully improves adherence. This source's null
result on that specific claim was scored generously on objectivity/honesty rather than discounted, since a
counter-narrative null result from an unaffiliated single author is exactly the kind of finding easiest to
wave away, and it deserves scrutiny rather than dismissal.)

## Key Findings
- Across a factorial design varying four structural properties of agent configuration files (CLAUDE-config /
  AGENTS-config / Cursor Rules), no structural variable produced a statistically detectable effect on instruction
  adherence after correcting for multiple testing — contradicting the common practitioner claim that headers,
  lists, and code fences make rules "land" more reliably than plain prose.
- The strongest effect found was not about file structure at all but about session dynamics: compliance
  degrades as the agent does more work within a single session, at approximately 5.6% lower odds of
  compliance per additional function generated.
- This implies documented conventions are least reliable exactly when they matter most — deep into a long
  agentic session, after the agent has already generated substantial code — which is also when a human is
  least likely to be reviewing line-by-line.
- The study used primarily Claude Sonnet 4.6 with Opus cross-validation across four TypeScript codebases and
  five coding tasks, giving the null result some cross-model robustness rather than resting on a single model
  quirk.

## Verified Quote(s)

**Location reference:** Abstract and results section (within-session compliance-decay finding).

> "Frontier coding agents read configuration files (CLAUDE.md, AGENTS.md, Cursor Rules) at session start and
> are expected to follow the conventions inside them."

> "each additional function the agent generates is associated with approximately 5.6% lower odds of
> compliance per step"

**Access status:** live (PDF; text extracted via abstract/HTML metadata after direct PDF parsing failed)

## Inclusion Decision
**Decision:** Core
**Rationale:** This is the only source in the track that directly and rigorously tests the mechanism
practitioners most often cite as making documentation "work" (structure/formatting) and finds it does not
hold up — while also surfacing a distinct, load-bearing finding (within-session compliance decay) that
strengthens the case for enforcement mechanisms that don't degrade as the session lengthens.
**Redundancy check:** No other kept source tests file-structure variables directly or measures within-session
decay; this is non-redundant even against the other two academic sources, which test different questions
(rule-type compliance and context-file task-performance value, respectively).
**Perspective category:** Academic

---
