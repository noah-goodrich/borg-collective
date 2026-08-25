# Source: How to Write a Great agents.md — Lessons from Over 2,500 Repositories (GitHub Blog)

**Full citation:** Nigh, Matt. "How to write a great agents.md: Lessons from over 2,500 repositories."
The GitHub Blog (github.blog), GitHub/Microsoft. November 19, 2025 (updated November 25, 2025).
**URL:** https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/
**Date accessed:** 2026-08-12
**Evidence level:** 7 (Expert Opinion/Thought Leadership — claims a pattern-scan of 2,500+ repositories but
discloses no methodology, sampling frame, or measurement for how "success" was determined, so it cannot be
treated as a rigorous study despite the large-N framing)
**Research topic area:** Mechanical enforcement vs. documented convention for AI agents

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 8/10 | Published on GitHub's official platform blog, the largest host of the exact artifact (agents.md) under discussion — strong platform authority, though the individual author's research credentials are not established. |
| 2 | Evidence Quality | 5/10 | Claims analysis of "over 2,500 agents.md files" but discloses no methodology, no criteria for what counted as "successful," and no statistics — an assertion of scale without the evidentiary transparency to verify it. |
| 3 | Currency | 7/10 | Published Nov 2025 (~9 months before access), reasonably current but predates the two 2026 academic studies kept in this track that test some of its central claims. |
| 4 | Intent | 6/10 | GitHub has a direct commercial interest in Copilot/agentic-tooling adoption and in agents.md as a GitHub-associated convention, which gives this piece a platform-promotional undertone alongside genuine educational intent. |
| 5 | Bias & Objectivity | 6/10 | Presents structural best practices (three-tier boundary systems, code-example-over-prose, executable commands early) with high confidence and no caveats, despite the claims being unfalsifiable from what's disclosed. |
| 6 | Logic & Coherence | 8/10 | Internally consistent, actionable, well-organized advice; reads as practically useful even without disclosed rigor. |
| 7 | Corroboration | 4/10 | Its central structural-formatting claims are directly contradicted by the later, more rigorous McMillan factorial study (arXiv:2605.10039), which found no detectable adherence effect from file-structure variables after correction for multiple testing. |
| 8 | Intellectual Honesty | 5/10 | Does not acknowledge or engage with the (admittedly later-published) academic finding that file-structure variables show no detectable adherence effect — presents structural advice as settled best practice rather than an open empirical question. |
| 9 | Specificity | 7/10 | Gives concrete, actionable structural patterns (three-tier "always/ask first/never" boundaries, real code snippets vs. prose descriptions). |
| 10 | Relevance | 7/10 | On-topic for the documented-convention side of the track, but focused on how to write conventions well rather than on the enforcement question directly. |

**Score band:** borderline

## Bias Guard Check
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings
- Advocates a "three-tier boundary system" for documented agent rules — always do / ask first / never do —
  as the structural pattern that separates agents.md files that work from ones that don't, positioning
  boundary-setting language as functionally load-bearing even without mechanical backing.
- Claims "most agent files fail because they're too vague," attributing poor agent compliance primarily to
  documentation quality rather than to the absence of enforcement — a framing that sits in direct tension
  with this track's stronger academic sources (RepoComplianceBench, the factorial file-structure study), both
  of which find compliance gaps that persist even with feedback/structure in place.
- Recommends real code examples over prose descriptions of style ("one real code snippet showing your style
  beats three paragraphs describing it"), a claim about format effectiveness that the later, more rigorous
  McMillan factorial study (arXiv:2605.10039) directly tested and found no statistically detectable structural
  effect for, after correction for multiple testing.
- Does still gesture toward enforcement as a validation step: the example AGENTS-config file includes instructions to
  run `markdownlint`, `npm run lint --fix`, and `npm test` — but frames these as steps the agent takes to
  self-check, not as external gates the agent cannot bypass.

## Verified Quote(s)

**Location reference:** "What works in practice" section and "Key takeaways" section.

> "One real code snippet showing your style beats three paragraphs describing it."

> "Building an effective custom agent isn't about writing a vague prompt; it's about providing a specific
> persona and clear instructions."

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** Kept at borderline specifically because it is the strongest available Institutional voice
articulating the mainstream practitioner position that better-written documentation (not enforcement) is the
fix for agent non-compliance — and because the direct empirical contradiction between this piece's structural
claims and the McMillan factorial study's null result is itself a citable, load-bearing tension for the
track's final synthesis (folklore vs. the one rigorous test of that folklore). It would not clear the bar on
evidence quality alone.
**Redundancy check:** Not redundant — no other kept source represents the "write better docs" camp with
platform-level authority; it is the necessary counterweight that makes the McMillan contradiction visible.
**Perspective category:** Institutional

---
