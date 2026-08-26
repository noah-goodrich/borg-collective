# Source: Harness Engineering for Coding Agent Users (Böckeler / martinfowler.com)

**Full citation:** Böckeler, Birgitta. "Harness engineering for coding agent users." martinfowler.com. April 2,
2026.
**URL:** https://martinfowler.com/articles/harness-engineering.html
**Date accessed:** 2026-08-12
**Evidence level:** 7 (Expert Opinion/Thought Leadership — a conceptual framework argued from consulting
experience, not a controlled study)
**Research topic area:** Practitioner discourse on agent-ready codebases

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 9/10 | Published on martinfowler.com, the most widely cited software-architecture publication in the industry; author is a Thoughtworks Distinguished Engineer specializing in AI-assisted delivery. |
| 2 | Evidence Quality | 6/10 | Argued from consulting-engagement experience and a proposed conceptual framework (the Guide/Sensor x Computational/Inferential matrix), not from a controlled study or measured data. |
| 3 | Currency | 9/10 | Published April 2026, squarely current; introduces durable vocabulary ("harness engineering") likely to remain referenced. |
| 4 | Intent | 8/10 | Genuine analytical/educational intent; Thoughtworks has an indirect commercial interest in AI-delivery consulting but the piece reads as even-handed thought leadership, not a sales pitch. |
| 5 | Bias & Objectivity | 8/10 | Explicitly hedges limits ("they can only go so far") and frames behavior as an unsolved problem rather than overselling the framework. |
| 6 | Logic & Coherence | 9/10 | Clear, internally consistent 2x2 framework distinguishing computational (deterministic) from inferential (LLM-judged) controls across maintainability, architecture, and behavior. |
| 7 | Corroboration | 8/10 | Corroborated by Akita's "Clean Code for AI Agents" and NimblePros's Clean Architecture piece (both converge on "more explicit structure helps agents"); tensions with Miller's vertical-slice contrarian argument on where that structure should live. |
| 8 | Intellectual Honesty | 8/10 | Names the hardest unsolved dimension (behavioral correctness) instead of implying the framework solves everything. |
| 9 | Specificity | 7/10 | Concrete framework elements (module boundaries as constraint rules, type-checking as a sensor) though less granular than a numbers-driven source. |
| 10 | Relevance | 10/10 | Directly named as a required lead for this track; explicitly treats architecture fitness as one of three harness-regulated dimensions for agent-maintained code. |

**Score band:** keep

## Bias Guard Check
- [x] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings
- Frames a coding-agent "harness" — guides (feedforward controls that steer the agent before it acts) plus
  sensors (feedback controls that let it self-correct after) — as the mechanism for building trust in
  AI-generated code, spanning two control types (computational/deterministic and inferential/LLM-judged)
  and regulating three dimensions: maintainability, architecture fitness, and functional behavior.
- In the "Harnessability" section, argues codebases vary in how amenable they are to harnessing at all:
  strong typing, clearly definable module boundaries, and abstracting frameworks are named as concrete
  properties that make a codebase's structure legible enough for automated architectural constraint rules
  to exist in the first place.
- In that same section, argues architecture choice is now partly an agent-governability decision:
  greenfield teams can "bake harnessability in from day one" through technology and architecture choices,
  while legacy codebases carrying accrued technical debt face the harder problem of retrofitting a harness
  precisely where it is hardest to build.
- Scope caveat: the article never names Clean Architecture, layered domain/usecase/infrastructure
  boundaries, or Protocol-based dependency injection specifically. Its claim is the more general one —
  that legible, well-bounded module structure of some kind is what makes automated enforcement possible —
  not that any particular layering pattern is the right one.

## Verified Quote(s)

**Location reference:** Body of the article, "Harnessability" section. The first quote is the section's
opening paragraph; the second follows the section's "Ambient affordances" sidebar, continuing the same
section's discussion (verified via curl fetch of martinfowler.com/articles/harness-engineering.html,
cross-checked with WebFetch).

> "Not every codebase is equally amenable to harnessing. A codebase written in a strongly typed language
> naturally has type-checking as a sensor; clearly definable module boundaries afford architectural
> constraint rules; frameworks like Spring abstract away details the agent doesn't even have to worry
> about and therefore implicitly increase the agent's chances of success."

> "Greenfield teams can bake harnessability in from day one - technology decisions and architecture choices
> determine how governable the codebase will be."

**Access status:** live

## Inclusion Decision
**Decision:** Core
**Rationale:** This is the single highest-authority source found for this track — a named-lead source from
the industry's most-cited software-architecture publication, explicitly framing architecture as one of
three dimensions a "harness" must regulate for agent-maintained code, and arguing for MORE explicit
structure, not less. Note the claim is at the level of "legible module boundaries and architecture choices
affect governability" — the article does not name Clean Architecture or its specific layering, so it
corroborates the general pro-structure direction of this track without being direct evidence for the
strict-Clean-Architecture variant specifically.
**Redundancy check:** Adds the institutional/consulting-authority perspective and the durable
"harness engineering" framing that no other kept source in this track provides; Akita and NimblePros reach
similar directional conclusions but from individual-practitioner and product-vendor angles respectively.
**Perspective category:** Institutional

---
