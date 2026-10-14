# Source: Zenn (Japanese, English machine translation): superpowers vs mattpocock/skills

**Full citation:** かなげん (kanagen). "Comparing superpowers vs. mattpocock/skills: Philosophy, Use Cases, and How to Choose." Zenn. 2026-06-09, updated 2026-06-17 (AI-translated English version).
**URL:** https://zenn.dev/kanagen/articles/claude-code-skills-superpowers-vs-mattpocock?locale=en
**Date accessed:** 2026-10-13
**Evidence level:** 7 (Expert opinion; hands-on comparison)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 4/10 | developer-author |
| 2 | Evidence Quality | 4/10 | hands-on, tables |
| 3 | Currency | 9/10 | 4 months old |
| 4 | Intent | 6/10 | community blog |
| 5 | Bias & Objectivity | 7/10 | balanced |
| 6 | Logic & Coherence | 7/10 | coherent |
| 7 | Corroboration | 6/10 | agrees w/ nocoders |
| 8 | Intellectual Honesty | 6/10 | "not which is better" |
| 9 | Specificity | 8/10 | tables, versions |
| 10 | Relevance | 8/10 | artifact accumulation |

Justifications (one line per dimension, same order):

1. Authority: Individual developer posting on a Japanese developer platform.
2. Evidence Quality: Based on installing and using both and comparing skill lists and behaviours; no measurements.
3. Currency: June 2026, before later v1.x changes.
4. Intent: Community knowledge-sharing platform.
5. Bias & Objectivity: Frames the choice as different problems, not a ranking.
6. Logic & Coherence: Comparison table and reasoning are consistent.
7. Corroboration: The hook-versus-manual split matches nocoders and Addy.
8. Intellectual Honesty: Says outright it is not "which one is better".
9. Specificity: Tables of skills with counts per library.
10. Relevance: Adds the cross-session artifact point (CONTEXT.md, ADRs, issues) relevant to checkpoints.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Superpowers is a "mechanism to enforce discipline on an agent"; Pocock's pack is "engineering fundamentals implemented as skills".
- Artifact model differs: Superpowers' plan-execute-finish consumption leaves no lasting asset across sessions, while Pocock's skills accumulate CONTEXT.md, ADRs and issues across sessions.
- Pocock has no sub-agent core feature at that date and integrates GitHub issues through three skills; Superpowers has sub-agents but no issue-tracker integration.
- The page is an AI-translated English rendering of a Japanese original (non-English coverage).

## Verified Quote(s)

**Location reference:** Section "Philosophical Differences" paragraph 3, and Introduction final sentence.

> mattpocock/skills accumulates knowledge into CONTEXT.md, ADRs, and GitHub Issues.

> the issue isn't "which one is better," but rather that they are trying to solve fundamentally different problems.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band, included as multilingual corroboration and for the cross-session artifact distinction; the hooks-vs-manual claim is corroborated by two other cards.

**Redundancy check:** The Superpowers comparison is redundant with nocoders, but the artifact-accumulation point is unique.

**Perspective category:** Practitioner
