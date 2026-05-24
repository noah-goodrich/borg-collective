# Source: Anthropic — How We Built Our Multi-Agent Research System

**Full citation:** Hadfield, J., Zhang, B., Lien, K., Scholz, F., Fox, J., & Ford, D.
"How we built our multi-agent research system." Anthropic Engineering Blog. June 13, 2025.
**URL:** https://www.anthropic.com/engineering/multi-agent-research-system
**Date accessed:** 2026-05-23
**Evidence level:** 5 (Practitioner case study with data)
**Research topic area:** T1 — Multi-agent team structures

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Authored by the engineering team that shipped the Claude Research feature. First-party operator of the system being described. Verifiable bylines. |
| 2 | Evidence Quality | 7/10 | Reports internal evals (BrowseComp, internal research eval) with explicit numbers (90.2% improvement, 15× token usage, 80% variance explained by tokens). Not peer-reviewed, no external replication. |
| 3 | Currency | 9/10 | Published June 2025; system is currently in production. Among the most-cited references in 2025–2026 agent literature. |
| 4 | Intent | 6/10 | Commercial — Anthropic benefits from positioning multi-agent as Claude's strength. Counterweight: the post openly states multi-agent is the wrong choice for many domains (coding, dependency-heavy tasks). |
| 5 | Bias & Objectivity | 7/10 | Names trade-offs explicitly: 15× token cost, coding not a good fit, synchronous bottlenecks. Doesn't strawman single-agent. |
| 6 | Logic & Coherence | 8/10 | Tight argument: research is breadth-first → parallelism wins → cost is justified when value is high. Each principle traces to a concrete failure mode they observed. |
| 7 | Corroboration | 8/10 | Corroborated by ZenML LLMOps Database write-up and ByteByteGo summary. Counterposed by Cognition's "Don't Build Multi-Agents." |
| 8 | Intellectual Honesty | 8/10 | Explicit list of where multi-agent fails: "most coding tasks involve fewer truly parallelizable tasks." Acknowledges synchronous execution as a bottleneck not yet solved. |
| 9 | Specificity | 9/10 | Concrete numbers (3-5 subagents in parallel, 3+ tools each, 90% time reduction, 1/2-4/10+ agent scaling rules). Reproducible heuristics. |
| 10 | Relevance | 9/10 | Directly addresses orchestrator-worker architecture and prompt engineering for production multi-agent systems — the heart of T1. |

**Composite score:**
9×0.25 + 7×0.20 + 9×0.10 + 6×0.10 + 7×0.10 + 8×0.05 + 8×0.05 + 8×0.05 + 9×0.05 + 9×0.05
= 2.25 + 1.40 + 0.90 + 0.60 + 0.70 + 0.40 + 0.40 + 0.40 + 0.45 + 0.45 = **7.95**

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(I find the orchestrator-worker pattern intuitively compelling for Noah's GTM use case. Scored
dimensions 5, 6, 8 harder to compensate.)

## Key Findings

1. **Orchestrator-worker pattern wins on breadth-first tasks.** A lead agent decomposes the
   query and spawns parallel subagents with isolated context windows. Beat single-agent Claude
   Opus 4 by 90.2% on internal research eval.
2. **Token usage is the dominant cost driver — and the dominant performance driver.**
   "Token usage by itself explains 80% of the variance" in BrowseComp performance; multi-agent
   systems use ~15× more tokens than chat.
3. **Multi-agent is wrong for dependency-heavy work.** "Most coding tasks involve fewer truly
   parallelizable tasks than research, and LLM agents are not yet great at coordinating and
   delegating to other agents in real time."
4. **Concrete scaling heuristics:** 1 agent for simple fact-finding, 2-4 subagents for direct
   comparisons, 10+ for complex research with clearly divided responsibilities.
5. **Prompting is the primary lever, not architecture.** "Effective prompting relies on
   developing an accurate mental model of the agent." Most failures came from vague task
   delegation, not the topology itself.
6. **Async execution is the next unsolved frontier.** Current production system is synchronous
   ("our lead agents execute subagents synchronously"), and that's the bottleneck.

## Verified Quote(s)

**Location reference:** Section "Benefits of a multi-agent system," paragraphs 4-6, and
section "Production reliability and engineering challenges," paragraph titled "Synchronous
execution creates bottlenecks."

> "Our internal evaluations show that multi-agent research systems excel especially for
> breadth-first queries that involve pursuing multiple independent directions simultaneously.
> We found that a multi-agent system with Claude Opus 4 as the lead agent and Claude Sonnet 4
> subagents outperformed single-agent Claude Opus 4 by 90.2% on our internal research eval."

> "In our data, agents typically use about 4× more tokens than chat interactions, and
> multi-agent systems use about 15× more tokens than chats. For economic viability,
> multi-agent systems require tasks where the value of the task is high enough to pay for the
> increased performance."

> "Most coding tasks involve fewer truly parallelizable tasks than research, and LLM agents
> are not yet great at coordinating and delegating to other agents in real time."

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Strong Include (Rule 1). Composite 7.95, not redundant — this is the most
specific first-party operational account of a shipping multi-agent system, with concrete
numbers and architectural choices. Defines the orchestrator-worker pattern that anchors the
T1 analysis.

**Redundancy check:** Overlaps with the Claude Agent SDK blog (Anthropic, Sep 2025) on tools
and subagents, but the Research-system post is the empirical case study; the SDK post is
product positioning. Both are kept; this one carries the load.

**Perspective category:** Institutional
