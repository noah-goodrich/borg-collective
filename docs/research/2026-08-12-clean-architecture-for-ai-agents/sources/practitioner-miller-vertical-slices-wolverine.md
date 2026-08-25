# Source: The Codebase Is the Prompt — Wolverine, Vertical Slices, and AI-Assisted Development (Jeremy D.
Miller)

**Full citation:** Miller, Jeremy D. "The Codebase Is the Prompt: Wolverine, Vertical Slices, and
AI-Assisted Development." The Shade Tree Developer. June 4, 2026.
**URL:** https://jeremydmiller.com/2026/06/04/the-codebase-is-the-prompt-wolverine-vertical-slices-and-ai-assisted-development/
**Date accessed:** 2026-08-12
**Evidence level:** 8 (Anecdotal/Personal Experience — direct first-hand framework-maintainer experience,
argued but not formally measured)
**Research topic area:** Practitioner discourse on agent-ready codebases

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 8/10 | Miller is the creator/maintainer of several well-known open-source .NET projects (Wolverine, Marten, historically StructureMap/FubuMVC), with 15+ years of widely-read public technical writing on architecture. |
| 2 | Evidence Quality | 6/10 | Grounded in direct experience building and using a real framework under AI-assisted development, with concrete mechanism (file/context loading), but no controlled measurement of token or accuracy deltas. |
| 3 | Currency | 9/10 | Published June 2026, directly addresses current agentic coding practice. |
| 4 | Intent | 7/10 | Personal technical blog; does promote his own framework (Wolverine) to a degree, but the core argument is a generalizable claim about layered vs. vertical-slice architecture, not a product pitch. |
| 5 | Bias & Objectivity | 6/10 | Has a mild self-interest in vertical-slice/Wolverine's design being validated, but is well known in the community for candid, nuanced technical writing rather than one-sided advocacy. |
| 6 | Logic & Coherence | 8/10 | Clear, specific causal mechanism: layered architecture scatters a single feature across many files, each of which must be pulled into context before a safe edit, degrading context-window efficiency. |
| 7 | Corroboration | 7/10 | Independently corroborated by Furdak's separate vertical-slice-for-Claude-Code piece; consistent with the general navigational-efficiency mechanism the SonarSource study measures, though that study does not test architecture style specifically. |
| 8 | Intellectual Honesty | 7/10 | States plainly that "the structure of your codebase is now, effectively, part of the prompt" — a direct, falsifiable claim rather than a hedge, and doesn't oversell vertical slices as a universal fix. |
| 9 | Specificity | 8/10 | Concrete claims about file counts loaded per feature and the "context pollution" mechanism, tied to specific Wolverine design choices. |
| 10 | Relevance | 10/10 | This is the strongest, most credible dissent found in this track's search against the "more layered structure always helps agents" consensus — exactly the disagreement the task asked to seek out. |

**Score band:** keep

## Bias Guard Check
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [x] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(Noted per the guard: most other kept sources in this track converge on "more explicit layered structure
helps agents," so this contrarian source was deliberately scored on its own merits — high authority,
specific mechanism, independent corroboration from Furdak — rather than discounted for cutting against the
majority view.)

## Key Findings
- Argues that traditional layered/Clean Architecture actively hinders AI coding agents because implementing
  one feature requires touching files scattered across controllers, requests, handlers, validators,
  repository interfaces, repository implementations, and mapping profiles — all of which must load into the
  agent's context window.
- States the core reframing directly: "The structure of your codebase is now, effectively, part of the
  prompt" — codebase layout is not neutral scaffolding but an active input that consumes or conserves
  context budget.
- Argues layered architecture, originally designed to manage human cognitive complexity, instead
  "manufactur[es] context pollution" for agents: "Most of what it loads is irrelevant to the task."
- Argues for vertical slice architecture (as implemented in his Wolverine framework) as the corrective:
  tightly co-locating everything one feature needs in a small, self-contained slice reduces the number of
  files an agent must load per change.
- Frames the payoff in direct operational-cost terms: "Fewer tokens loaded per task is a direct, recurring
  cost reduction every single time an agent touches the code" — an efficiency argument structurally similar
  to Akita's, but pointing to the opposite architectural remedy (fewer layers, not more granular files
  within layers).

## Verified Quote(s)

**Location reference:** Body of the article, sections contrasting layered-architecture file scatter with
Wolverine's vertical-slice design.

> "The structure of your codebase is now, effectively, part of the prompt."

> "Every one of those files has to be pulled into the agent's context before it can safely make a change.
> Most of what it loads is irrelevant to the task."

> "The architecture that was supposed to manage complexity ends up manufacturing context pollution."

**Access status:** live

## Inclusion Decision
**Decision:** Core
**Rationale:** This is the track's key finding on the "does anyone argue for flatter/simpler structure"
question — a high-authority OSS architect directly arguing that classic layered/Clean Architecture harms
agent performance via context pollution, and that feature-colocated (vertical-slice) structure serves
agents better. This is genuine disagreement, not a straw-man contrarian.
**Redundancy check:** No other kept source argues against layered architecture with this level of authority
and mechanism-level specificity; Furdak's piece corroborates the same conclusion but from a much smaller,
less established practitioner voice, so Miller is the stronger of the two and is kept as Core while Furdak
is kept as corroborating Boots-on-the-ground evidence.
**Perspective category:** Contrarian

---
