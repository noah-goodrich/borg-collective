# Source: Keeping AI Agents In Line With Clean Architecture (NimblePros)

**Full citation:** Blake, Barret. "Keeping AI Agents In Line With Clean Architecture." NimblePros
Blog. June 23, 2026.
**URL:** https://blog.nimblepros.com/blogs/ai-agents-clean-architecture/
**Date accessed:** 2026-08-12
**Evidence level:** 7 (expert opinion / thought leadership; informed practitioner argument, not
formal research)
**Research topic area:** Empirical & academic evidence — practitioner counterpoint (pro-structure
angle)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 5/10 | NimblePros is a .NET consulting boutique with real domain credibility in Clean Architecture specifically (the firm is associated with well-known Clean Architecture template/tooling authors in the .NET ecosystem), but this is a company blog, not independent research. |
| 2 | Evidence Quality | 3/10 | One illustrative code example (an architecture test catching a `SendGridClient` leak into application code); no controlled comparison, no data, no benchmark. |
| 3 | Currency | 9/10 | Published June 2026, current to the live Claude-Code-era debate. |
| 4 | Intent | 4/10 | The firm sells Clean Architecture templates/consulting services; the article functions as content marketing for that offering, a direct commercial conflict of interest on the very question it's arguing. |
| 5 | Bias & Objectivity | 4/10 | One-sided advocacy piece; does not engage with counter-evidence (e.g., the token/navigation costs of layering, or studies finding null/negative effects). |
| 6 | Logic & Coherence | 7/10 | The internal argument is coherent: agents lack architectural judgment, so visible folder structure, explicit dependency rules, and automated architecture tests substitute for the intuition a human would bring. |
| 7 | Corroboration | 5/10 | Aligns directionally with the positive framing in "Formal Architecture Descriptors" (arXiv:2604.13108); directly contradicted by the quantified −9.1pp Clean Architecture penalty in "Constraint Decay" (arXiv:2605.06445). |
| 8 | Intellectual Honesty | 4/10 | Does not acknowledge or address the existence of counter-evidence or trade-offs; presents Clean Architecture as a clean win with no cost side. |
| 9 | Specificity | 5/10 | One concrete example given (the SendGridClient architecture-test catch); otherwise the claims are general mechanisms rather than measured outcomes. |
| 10 | Relevance | 9/10 | Squarely on-topic: this is a practitioner making the mainstream pro-Clean-Architecture-for-agents case that the academic sources in this track test empirically. |

**Score band:** borderline

## Bias Guard Check
- [x] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(Given the empirical sources in this track lean toward a null-or-negative correctness effect for
layering, this piece's unqualified pro-structure advocacy reads as the less-supported position —
noted per the guard; scored on its own argumentative merits rather than penalized for disagreeing
with the stronger evidence.)

## Key Findings
- Argues AI coding agents lack the architectural judgment human engineers bring intuitively, so
  they will optimize for the fastest local solution unless explicit guardrails exist.
- Identifies three recurring agent failure modes the author attributes to lack of structure:
  infrastructure leaking into application layers, business-rule duplication across the codebase,
  and established patterns being silently bypassed.
- Proposes three concrete mechanisms as the fix: (1) a visible, conventional folder structure that
  agents can pattern-match against instead of inventing parallel approaches, (2) explicit
  dependency rules stated in the codebase, and (3) automated architecture tests enforced at build
  time.
- Demonstrates the third mechanism with a specific example: an architecture test that fails a
  build when an agent injects a `SendGridClient` directly into application-layer code, forcing the
  agent toward a proper abstraction.
- Closes by reframing the trade-off as sustainability vs. velocity, not structure vs. speed: teams
  that build "the clearest architectural guardrails" (not the teams that let agents write the most
  code) are the ones that succeed, because Clean Architecture "isn't an obstacle to velocity. It's
  what makes velocity sustainable."

## Verified Quote(s)

**Location reference:** Closing two sentences of the "Conclusion" section (verified via curl fetch
of blog.nimblepros.com/blogs/ai-agents-clean-architecture/, cross-checked with WebFetch).

> "In the age of AI-assisted development, Clean Architecture isn’t an obstacle to velocity. It’s
> what makes velocity sustainable."

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** Kept as borderline specifically to represent the mainstream pro-Clean-Architecture
practitioner position with a real, credible-in-its-niche author (a Clean-Architecture-focused
.NET consultancy) rather than letting this track lean entirely on academic/contrarian sources.
Without it, the track would understate how strongly practitioners currently believe the opposite
of what the strongest empirical evidence (Constraint Decay) finds.
**Redundancy check:** Not redundant with the academic sources — it is the clearest "Practitioner"
category voice found, and it argues the opposite direction from the vertical-slicing dev.to piece,
giving the track a genuine for/against practitioner pair.
**Perspective category:** Practitioner

---
