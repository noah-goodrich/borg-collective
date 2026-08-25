# Source: The Codebase Is the Prompt — Wolverine, Vertical Slices, and AI-Assisted Development

**Full citation:** Miller, Jeremy D. "The Codebase Is the Prompt: Wolverine, Vertical Slices, and AI-Assisted
Development." The Shade Tree Developer (personal blog). June 4, 2026.
**URL:** https://jeremydmiller.com/2026/06/04/the-codebase-is-the-prompt-wolverine-vertical-slices-and-ai-assisted-development/
**Date accessed:** 2026-08-12
**Evidence level:** 7 (Expert Opinion/Thought Leadership — a domain-expert practitioner argument, not a
controlled study; the author draws on general industry trends rather than a documented before/after case study)
**Research topic area:** Context engineering and agent navigation cost — direct architectural comparison of
layered (Clean/Hexagonal) vs. vertical-slice (colocated) organization, framed explicitly in agent-context terms

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 7/10 | Named, verifiable open-source maintainer (Wolverine, Marten, and the FubuMVC lineage) and founder of JasperFx Software; a genuine long-standing domain expert in .NET application architecture, though not an AI/ML researcher. |
| 2 | Evidence Quality | 3/10 | Presents architectural philosophy and reasoning, not a documented case study, benchmark, or before/after measurement; explicitly synthesizes "what practitioners keep arriving at" rather than the author's own controlled test. |
| 3 | Currency | 9/10 | Published June 2026, engages current Claude Code-era practice directly. |
| 4 | Intent | 7/10 | Genuine technical reasoning to justify a design choice in his own open-source framework (Wolverine), which has a vertical-slice orientation — a real but disclosed self-interest, not concealed marketing. |
| 5 | Bias & Objectivity | 5/10 | Advocacy piece for vertical-slice architecture, in which the author has professional investment via Wolverine; does not substantively engage the maintainability/testability case for layering that Clean Architecture proponents would raise. |
| 6 | Logic & Coherence | 8/10 | Clear, internally consistent causal chain: layer-spread code forces broad loading -> signal-to-noise collapses in the context window -> agent reconstructs flow from fragments -> that reconstruction is where hallucination happens. |
| 7 | Corroboration | 6/10 | Independently arrives at Anthropic's "smallest high-signal token set" principle and the Formal Architecture Descriptors paper's "reconstruct architectural context" framing, from an application-architecture practitioner's angle rather than an AI-research angle. |
| 8 | Intellectual Honesty | 6/10 | Frames the claim accurately as an emerging practitioner consensus rather than dressing up personal opinion as measured data; does not claim numbers he doesn't have. |
| 9 | Specificity | 6/10 | Concrete about mechanism (files pulled into context per change, signal-to-noise collapse, token cost per touch) and anchored to a real, named framework (Wolverine) rather than a hypothetical example. |
| 10 | Relevance | 10/10 | The single most directly on-topic source found in this track — explicitly compares layered vs. colocated architecture and names the agent-context cost of spreading one operation across layers. |

**Score band:** keep

## Bias Guard Check
- [x] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings
- Argues that feature-organized, vertical-slice code is "simply easier — and cheaper — for an agent to work in"
  than layer-organized code, because every layer-spanning change (Clean/Hexagonal architecture) forces the agent
  to pull files from multiple technical tiers into context before it can safely make a change.
- Frames layered architecture's cost in signal-to-noise terms: most of what gets loaded to satisfy the layering
  convention is irrelevant to the specific task, so relevant signal is diluted by structurally-mandated but
  task-irrelevant files.
- Claims a direct causal link between having to "reconstruct a flow from fragments strewn across layers" and the
  conditions under which agents hallucinate — i.e., cross-layer reconstruction is specifically where errors are
  introduced, not just where cost is incurred.
- Frames the token cost as a recurring, per-touch cost: "fewer tokens loaded per task is a direct, recurring
  cost reduction every single time an agent touches the code" — a maintenance-lifetime argument, not a one-time
  onboarding argument.
- Positions this as the emerging conclusion of a broader practitioner conversation ("the dominant theme in
  writing about AI-ready codebases is locality of reference"), not a claim original to this one post.

## Verified Quote(s)
**Location reference:** Section "Why layered architectures fight the agent," second paragraph (the
opening paragraph is the "Picture the canonical 'clean' layered solution..." scene-setting passage;
confirmed via direct curl fetch 2026-08-12).

> Every one of those files has to be pulled into the agent's context before it can safely make a change. Most
> of what it loads is irrelevant to the task. The signal-to-noise ratio in the context window collapses, and
> that's exactly the condition under which agents start guessing — inventing abstractions you didn't ask for,
> "fixing" error cases that can't happen, and drifting away from the intent of the change.

**Location reference:** Section "Why layered architectures fight the agent," concluding sentence.

> The conclusion practitioners keep arriving at is that feature-organized, vertical-slice code is simply easier
> — and cheaper — for an agent to work in than layer-organized code.

**Location reference:** Section "Why compression is the feature for AI."

> It never has to reconstruct a flow from fragments strewn across layers, which is precisely the situation where
> agents hallucinate.

**Access status:** live

## Inclusion Decision
**Decision:** Core
**Rationale:** The most precise, directly-on-target statement of this track's exact research question found
anywhere in the search — a named, credentialed architecture practitioner explicitly arguing that spreading one
operation across Clean-Architecture-style layers has a measurable agent-context cost, and naming the mechanism
(signal-to-noise collapse, cross-layer reconstruction as hallucination trigger).
**Redundancy check:** Not redundant with the Anthropic or Formal Architecture Descriptors sources — those argue
for minimal, well-signposted context generally; this is the only kept source arguing the specific structural
claim (layering itself, independent of documentation, is the cost driver) with a named real-world framework as
the anchor.
**Perspective category:** Practitioner

---
