# Source: Formal Architecture Descriptors as Navigation Primitives for AI Coding Agents

**Full citation:** Jin, Ruoqi. "Formal Architecture Descriptors as Navigation Primitives for AI
Coding Agents." arXiv:2604.13108. April 11, 2026.
**URL:** https://arxiv.org/abs/2604.13108
**Date accessed:** 2026-08-12
**Evidence level:** 3 (mixed controlled experiments + large observational field study; preprint,
not peer-reviewed, single author)
**Research topic area:** Empirical & academic evidence — codebase structure vs. agent performance
(positive-effect angle)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 4/10 | Single-author preprint; no stated institutional affiliation found on the paper or listing page; no independent replication. |
| 2 | Evidence Quality | 6/10 | Three complementary studies (24-task controlled experiment, 15-task artifact-vs-process comparison, 7,012-session observational field study) with reported statistics (Wilcoxon p=0.009, Cohen's d=0.92 etc.), but the two controlled experiments have small task counts. |
| 3 | Currency | 9/10 | Published April 2026, current to this literature. |
| 4 | Intent | 5/10 | The paper proposes and then validates the author's own artifact (an S-expression descriptor format and the open-sourced "Forge" toolkit) — a degree of self-interest in a positive result. |
| 5 | Bias & Objectivity | 5/10 | Author both designed and evaluated their own navigation-aid format; no independent evaluator. |
| 6 | Logic & Coherence | 7/10 | Three-study structure (controlled -> artifact-vs-process -> field) is a coherent escalation from lab to production-scale observation. |
| 7 | Corroboration | 6/10 | Directionally aligns with "How Much Static Structure Do Code Agents Need?" (arXiv:2606.26979, triaged out for redundancy in this track) on structural navigation aids helping; tensions with Constraint Decay's negative finding on architectural constraints. |
| 8 | Intellectual Honesty | 7/10 | Reports a genuine null result within its own scope (no significant difference between S-expression, JSON, YAML, and Markdown descriptor formats) and an unflattering finding for one format (YAML silently corrupted 50% of injected errors) rather than only reporting favorable results. |
| 9 | Specificity | 8/10 | Concrete, falsifiable numbers throughout: 33-44% navigation-step reduction, 100% vs 80% localization accuracy, 52% IQR reduction across 7,012 sessions. |
| 10 | Relevance | 8/10 | Directly on-topic, but tests *supplementary architecture documentation given to the agent*, not whether the underlying codebase is itself organized as layered/Clean Architecture — a related but distinct variable from this track's core question. |

**Score band:** borderline

## Bias Guard Check
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings
- In a controlled experiment (24 code-localization tasks, Claude Sonnet 4.6, temperature=0),
  providing agents with a formal architecture descriptor reduced navigation steps by 33-44%
  relative to no descriptor (Wilcoxon p=0.009, Cohen's d=0.92).
- An automatically generated descriptor achieved 100% localization accuracy versus 80% blind
  accuracy without any architecture context (p=0.002, d=1.04), showing the effect holds even
  without a human writing the descriptor by hand.
- An observational field study across 7,012 real Claude Code sessions found formal descriptors
  reduced the interquartile range of per-session explore/edit ratios by 52% (from 2.24 to 1.08),
  i.e., more consistent, less erratic agent behavior in production use, not just in the lab.
- Descriptor *format* did not matter much: no significant difference was detected between
  S-expression, JSON, YAML, and Markdown representations on the primary navigation metrics —
  except that YAML silently corrupted 50% of injected structural-completeness errors, while
  S-expressions detected all of them, an important reliability caveat buried under the "no format
  difference" headline.
- This paper measures the value of an *explicit architecture description artifact* handed to the
  agent, not the effect of the codebase's actual physical organization (layered vs. flat) — a
  scope distinction worth keeping separate from the Constraint Decay and vertical-slicing findings
  in this track.

## Verified Quote(s)

**Location reference:** Abstract, single sentence (re-fetched and confirmed 2026-08-12 directly against
arxiv.org/abs/2604.13108's live abstract text via curl, character-for-character).

> "architecture context reduces navigation steps by 33-44% (Wilcoxon p=0.009, Cohen's d=0.92), with no
> significant format difference detected across S-expression, JSON, YAML, and Markdown."

**Correction history (2026-08-12):** the original card elided the "(Wilcoxon p=0.009, Cohen's d=0.92)"
parenthetical with no ellipsis mark. A first correction attempt made things worse — it split the sentence
into two fragments, added a fabricated trailing word ("representations") never checked against the real
text, and incorrectly asserted the two clauses came from separate sub-experiments (that framing exists
only in the paper's expanded full-text discussion section, not on the abstract page this card actually
cites). This is now the full, real, single sentence exactly as it appears on the cited abstract page.

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** Included as borderline: it is the most rigorous available evidence that giving
agents explicit structural/architectural information (as opposed to embedding that structure in
the code layout itself) measurably improves navigation efficiency and consistency — a real and
relevant finding, but the single-author preprint with a self-validated artifact, plus the scope
gap (descriptor-as-documentation vs. code-as-organized) keeps it out of "Core."
**Redundancy check:** Adds the "explicit descriptor as navigation aid" construct, which the other
kept sources in this track do not test (Constraint Decay tests the code's own layering; the
SonarSource paper tests lint cleanliness; the practitioner sources discuss code organization, not
supplementary documentation). Not redundant.
**Perspective category:** Academic

---
