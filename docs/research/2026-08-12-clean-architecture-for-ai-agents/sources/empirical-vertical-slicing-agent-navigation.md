# Source: Coding Agents as a First-Class Consideration in Project Structures (DEV Community)

**Full citation:** Ortiz, Basti. "Coding Agents as a First-Class Consideration in Project
Structures." DEV Community. January 5, 2026.
**URL:** https://dev.to/somedood/coding-agents-as-a-first-class-consideration-in-project-structures-2a6b
**Date accessed:** 2026-08-12
**Evidence level:** 8 (anecdotal / personal experience; author explicitly frames claims as
observational, not data-backed)
**Research topic area:** Empirical & academic evidence — practitioner counterpoint (anti-layering
angle)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 3/10 | Individual author (AI Product Engineer, B.Sc. Computer Science) with no institutional research backing; personal blog platform (DEV Community), not a peer-reviewed or editorially vetted outlet. |
| 2 | Evidence Quality | 2/10 | No controlled comparison or measurement; relies on an informal, uncredited "40% Rule" and the author's own observed agent-exploration patterns. Author explicitly acknowledges this. |
| 3 | Currency | 7/10 | Dated January 2026; current to the topic window, though on the older edge of the sources gathered for this track. |
| 4 | Intent | 8/10 | Reads as a genuine firsthand reflection on agent behavior, not selling a product or service. |
| 5 | Bias & Objectivity | 5/10 | Argues one-sidedly against horizontal layering without engaging counterarguments, but is transparent that the claims are anecdotal rather than dressing them up as data. |
| 6 | Logic & Coherence | 7/10 | The proposed mechanism is internally coherent and plausible: horizontal layering forces cross-directory jumps and dumps unrelated code into context, while vertical slices keep everything an agent needs for one feature collocated. |
| 7 | Corroboration | 7/10 | Its central claim — that layered/Clean-Architecture-style organization degrades agent performance — is independently corroborated by the controlled, quantified finding in "Constraint Decay" (arXiv:2605.06445, −9.1pp for Clean Architecture), a rare case of unverified practitioner intuition matching a controlled academic result. |
| 8 | Intellectual Honesty | 8/10 | Explicitly labels its own evidence as "construction and organization" reasoning rather than hard data — unusually candid for a piece arguing a strong position. |
| 9 | Specificity | 6/10 | Concrete mechanistic claims (directory jumps, `ls` calls, context-window noise from monolithic Service classes) even though none are quantified. |
| 10 | Relevance | 9/10 | Directly on-topic: an explicit argument that horizontal/layered architecture (the organizational hallmark of strict Clean Architecture) actively hurts agent navigation, in favor of vertical slicing. |

**Score band:** borderline

## Bias Guard Check
- [x] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(This source's anti-layering conclusion matches the direction of the strongest quantified evidence
in this track — Constraint Decay's negative finding — which is exactly the situation where it's
easiest to under-scrutinize a weak source because it says what stronger evidence also says. Scored
its evidence quality and objectivity as low as an unrelated null-agreement source would be, per the
guard.)

## Key Findings
- Argues that horizontally-layered (classical N-tier / Clean-Architecture-style) codebases scatter
  a single feature's logic across separate "services," "controllers," and "models" directories,
  forcing an agent into repeated directory jumps and `ls` calls to reassemble context for one task.
- Claims monolithic Service classes dump large amounts of unrelated code into the agent's context
  window as noise, degrading signal even when the agent only needs a small slice of that file.
- Advocates vertically-sliced, feature-driven project structure instead: self-contained feature
  modules that collocate everything one change needs, enabling "depth-first" exploration and
  reducing merge conflicts on concurrent agent-driven work.
- Invokes an informal "40% Rule" (uncredited/unsourced anecdotal claim that LLM output quality
  degrades once context-window usage passes roughly 40%) as a supporting mechanism for why
  minimizing irrelevant-file noise matters.
- Explicitly caveats that the argument rests on construction/organization reasoning and observed
  agent behavior patterns rather than a controlled study — the author does not claim empirical
  proof.

## Verified Quote(s)

**Location reference:** Conclusion, recommendations bullet list (verified via WebFetch of
dev.to/somedood/coding-agents-as-a-first-class-consideration-in-project-structures-2a6b; corrected
2026-08-12 after Phase 3.5 independent verification found this quote sits in the article's Conclusion
summary, not its argument body as originally claimed — the quote text itself was already verbatim and
correctly attributed).

> "narrow depth-first slices of the codebase encourage highly selective and cohesive exploration"

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** Kept as the lowest-scoring source in this track's final set, on triangulation
grounds: it is the clearest "boots-on-the-ground" practitioner voice arguing that layered
structure specifically harms agent navigation, and — despite weak evidence quality standing
alone — its direction of effect is independently corroborated by the controlled Constraint Decay
study, which is exactly the kind of practitioner-intuition-meets-controlled-data pairing this
research pipeline is designed to surface. Without it, the "anti-layering" position in this track
would rest on academic evidence alone, understating how organically practitioners are arriving at
the same conclusion.
**Redundancy check:** Not redundant with NimblePros (opposite conclusion, same question) or with
Constraint Decay (controlled data vs. firsthand practitioner reasoning on the same claim) — it
fills the "Boots-on-the-ground" perspective slot no other kept source in this track occupies.
**Perspective category:** Boots-on-the-ground

---
