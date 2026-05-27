# Source: Cognition — Don't Build Multi-Agents

**Full citation:** Yan, Walden. "Don't Build Multi-Agents." Cognition AI Blog. June 12, 2025.
**URL:** https://cognition.ai/blog/dont-build-multi-agents
**Date accessed:** 2026-05-23
**Evidence level:** 7 (Expert opinion / thought leadership)
**Research topic area:** T1 — Multi-agent team structures (contrarian)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Walden Yan is a Cognition co-founder/research lead. Cognition built Devin, one of the more-shipped agent products. Verifiable practitioner credentials. |
| 2 | Evidence Quality | 5/10 | No data tables or quantitative benchmarks. Builds the case via reasoning from first principles and concrete contrived examples (Flappy Bird, edit-apply models). Genuine production experience implied but not documented. |
| 3 | Currency | 9/10 | June 2025, addresses the 2024–2025 multi-agent hype cycle directly. |
| 4 | Intent | 7/10 | Promotes Cognition's single-threaded-agent philosophy and recruits engineers. But the position contradicts the cheap-marketing path (multi-agent is the buzzy framing) — credible because it cuts against incentive. |
| 5 | Bias & Objectivity | 5/10 | Strong opinion piece. Explicitly names OpenAI Swarm and Microsoft AutoGen as "the wrong way of building agents." Doesn't engage seriously with Anthropic's published evidence to the contrary. |
| 6 | Logic & Coherence | 7/10 | Two principles (share context, actions carry implicit decisions) are tightly argued. The "Flappy Bird" example holds up. The leap from "Cognition couldn't make it work" to "no one should build multi-agents" is overreach. |
| 7 | Corroboration | 7/10 | Corroborated by the Cemri et al. MASFT paper (failure rates 41-86.7%). Contradicted by Anthropic's 90.2% claim, though Anthropic's evals are research-task-specific. |
| 8 | Intellectual Honesty | 7/10 | Acknowledges "I'm optimistic about the long-term possibilities" and "our theories are likely not perfect." Doesn't disclose the obvious counter-evidence from Anthropic. |
| 9 | Specificity | 6/10 | Names tools (Swarm, AutoGen, MetaGPT, Devin's edit-apply model history) and contrasts a specific bad pattern (parallel subagents without shared context) with single-threaded linear agents with a compression step. No metrics. |
| 10 | Relevance | 9/10 | Directly addresses the central T1 question — when not to build multi-agent. Required reading for any honest analysis of the architecture choice. |

**Composite score:**
8×0.25 + 5×0.20 + 9×0.10 + 7×0.10 + 5×0.10 + 7×0.05 + 7×0.05 + 7×0.05 + 6×0.05 + 9×0.05
= 2.00 + 1.00 + 0.90 + 0.70 + 0.50 + 0.35 + 0.35 + 0.35 + 0.30 + 0.45 = **6.90**

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [x] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(I'm sympathetic to the orchestrator-worker pattern Cognition criticizes. Scored dimensions
5, 6, and 8 more generously to compensate for the temptation to penalize.)

## Key Findings

1. **Two principles for context engineering:** "Share context, and share full agent traces,
   not just individual messages" and "Actions carry implicit decisions, and conflicting
   decisions carry bad results."
2. **Parallel subagents without shared context produce inconsistent work** — the Flappy Bird
   example: one subagent builds a Super Mario background, another builds a bird in a
   different visual style, the orchestrator can't reconcile.
3. **Single-threaded linear agents with periodic context compression are Cognition's
   recommended default.** Compression is hard (Cognition fine-tunes a small model for it) but
   the resulting agent is more reliable.
4. **Claude Code's subagents are intentionally limited.** "It never does work in parallel
   with the subtask agent, and the subtask agent is usually only tasked with answering a
   question, not writing any code." Cited as evidence that Anthropic also acknowledges the
   coordination problem.
5. **Multi-agent will eventually work when single-agent communication with humans improves.**
   Yan is not anti-multi-agent in principle, only against the current state of the art.

## Verified Quote(s)

**Location reference:** Sections "A Theory of Building Long-running Agents" (Principle 1
callout) and "Multi-Agents" subsection.

> "Principle 1
> Share context, and share full agent traces, not just individual messages"

> "Principle 2
> Actions carry implicit decisions, and conflicting decisions carry bad results"

> "While I'm optimistic about the long-term possibilities of agents collaborating with one
> another, it is evident that in 2025, running multiple agents in collaboration only results
> in fragile systems. The decision-making ends up being too dispersed and context isn't able
> to be shared thoroughly enough between the agents."

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Diversity Include (Rule 2) + Strong Include (Rule 1 borderline at 6.90). This
is the strongest contrarian voice in the corpus — the perspective category for the entire
research depends on this source carrying weight. Without it, T1 collapses into Anthropic-only
echo.

**Redundancy check:** Adjacent to Cemri et al. (MAS failure taxonomy) but Cemri is academic
empirical work; Yan is the practitioner-from-production view. Both kept, different evidence
types.

**Perspective category:** Contrarian
