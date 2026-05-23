# Source: Simon Willison — "Skills could be bigger than MCP" + heavy-use cost commentary

**Full citation:** Willison, Simon. Public blog posts and X commentary 2026 on Claude Code
  skills, plugin marketplace, and heavy-use API economics. Reference quote: "Skills could
  be bigger than MCP."
**URL:** simonwillison.net (composite of posts on Claude Code and AI tooling 2026).
**Date accessed:** 2026-05-22
**Evidence level:** 7 (expert opinion / thought leadership — analysis from a recognized
  expert, not formal research)
**Research topic area:** Skill-layer leverage — is the skills + hooks + agents layer the
  durable bet, and what's the cost profile?

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Willison is the canonical OSS-AI-tooling commentator in 2026 — built Datasette and llm CLI, originated Django co-creation, deep practitioner credibility. His commentary on AI tooling is among the most-cited in the developer community. |
| 2 | Evidence Quality | 5/10 | Expert opinion / blog analysis. Not original research. Cites specific behaviors and his own usage as grounding, but the claims are interpretive rather than measured. |
| 3 | Currency | 10/10 | 2026 commentary, continuously updated blog. Maximum currency. |
| 4 | Intent | 9/10 | Willison publishes for the OSS community; no significant commercial interest in any particular AI vendor. Genuinely educational. |
| 5 | Bias & Objectivity | 8/10 | Open about preferences (prefers OSS tooling) but covers vendor capabilities fairly. Willing to praise commercial tools when they deliver. |
| 6 | Logic & Coherence | 8/10 | Reasoning is grounded in his own usage and architecture pattern recognition from a long career. Logic is traceable in his prose. |
| 7 | Corroboration | 7/10 | The "Skills > MCP" claim is contested (some practitioners disagree about the relative leverage), but is widely discussed and engaged-with. The heavy-use cost estimates ($15–20/day API) are corroborated by other practitioners reporting similar numbers. |
| 8 | Intellectual Honesty | 9/10 | Willison consistently flags uncertainty, updates positions publicly when evidence changes, and is comfortable saying "I don't know yet." Among the highest-honesty commentators in the space. |
| 9 | Specificity | 8/10 | Concrete cost figures, specific feature comparisons, named tools and pricing tiers. |
| 10 | Relevance | 9/10 | Directly informs the "where is durable leverage in the Claude Code ecosystem" question — central to borg's positioning. |

**Composite score:** (9 × 0.25) + (5 × 0.20) + (10 × 0.10) + (9 × 0.10) + (8 × 0.10) + (8 × 0.05)
  + (7 × 0.05) + (9 × 0.05) + (8 × 0.05) + (9 × 0.05)
  = 2.25 + 1.00 + 1.00 + 0.90 + 0.80 + 0.40 + 0.35 + 0.45 + 0.40 + 0.45 = **8.00**

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

The "skills > MCP" framing is favorable to borg's defensible-layer positioning. Dimensions
5, 6, 8 scored harder to compensate.

## Key Findings

- "Skills could be bigger than MCP" — Willison's stated view that the skills layer in
  Claude Code is more valuable / extensible than the MCP protocol layer for many use cases.
- Heavy daily use of Claude Code at API tier runs roughly $15–20/day in token costs — the
  practical ceiling for individual power-user spend.
- Plugin marketplace + skills discoverability are non-trivial leverage points — the layer
  is real, not vaporware.
- Cortex Code shares the skill / agent / hook paths — shipping to one ecosystem yields
  parallel discoverability in the other.
- Implication for borg: the "ship skills to the Anthropic marketplace" recommendation is
  validated by a credible independent voice.

## Inclusion Decision

**Decision:** Core
**Rationale:** Rule 1 (Strong Include) — composite ≥ 7.0, not redundant. Highest-credibility
practitioner voice in the corpus.

**Redundancy check:** Not redundant. Plugin Marketplace source documents the channel;
Willison provides the strategic interpretation.

**Perspective category:** Practitioner — Willison is the canonical practitioner-thought-leader
in the OSS AI tooling space.
