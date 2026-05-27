# Source: Anthropic — Building Agents with the Claude Agent SDK

**Full citation:** Shihipar, T. (with Vorwerck, M., Wang, S., Isken, A., Wu, C., Bradwell, K.,
Bricken, A., Bhat, A.). "Building agents with the Claude Agent SDK." Claude / Anthropic Blog.
September 29, 2025.
**URL:** https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk
(canonical: https://claude.com/blog/building-agents-with-the-claude-agent-sdk)
**Date accessed:** 2026-05-23
**Evidence level:** 7 (Expert opinion / thought leadership — product positioning + design
guidance)
**Research topic area:** T5 — Practical tool stack

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Authored by the Claude Agent SDK product team. First-party documentation of the SDK Noah's stack already depends on. |
| 2 | Evidence Quality | 5/10 | No benchmarks or numbers. Pattern guidance and design heuristics drawn from internal use ("Claude Code has become far more than a coding tool. At Anthropic, we've been using it for deep research, video creation, and note-taking"). |
| 3 | Currency | 10/10 | September 29, 2025, alongside the Sonnet 4.5 launch — current. |
| 4 | Intent | 4/10 | Product marketing + adoption pitch for the SDK. Genuine guidance buried inside a launch announcement. |
| 5 | Bias & Objectivity | 5/10 | Promotes Anthropic's stack (MCP, Skills, SDK). Doesn't compare to CrewAI/LangGraph/AutoGen. |
| 6 | Logic & Coherence | 8/10 | The gather-context → take-action → verify loop is a clean model. The email-agent worked example is concrete. |
| 7 | Corroboration | 8/10 | Aligned with the multi-agent research-system post (June 2025) and the AntStack field guide. The agent-loop framing is now standard practitioner vocabulary. |
| 8 | Intellectual Honesty | 6/10 | Mentions trade-offs (semantic search "less accurate, more difficult to maintain, and less transparent" than agentic search) but rarely says where the SDK doesn't fit. |
| 9 | Specificity | 7/10 | Names the four context-gathering features (agentic search, semantic search, subagents, compaction), four action tools (tools, bash, code, MCPs), three verification approaches (rules, visual, LLM-as-judge). |
| 10 | Relevance | 9/10 | Directly relevant — this is the SDK Noah builds on. Defines the primitives any GTM agent stack will compose. |

**Composite score:**
9×0.25 + 5×0.20 + 10×0.10 + 4×0.10 + 5×0.10 + 8×0.05 + 8×0.05 + 6×0.05 + 7×0.05 + 9×0.05
= 2.25 + 1.00 + 1.00 + 0.40 + 0.50 + 0.40 + 0.40 + 0.30 + 0.35 + 0.45 = **7.05**

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(I find the gather-context/act/verify loop intuitively useful and find Anthropic's tool-design
prescriptions sensible. Scored 5, 6, 8 harder accordingly.)

## Key Findings

1. **The Claude Agent SDK is Claude Code's harness, generalized to non-coding work.**
   "The agent harness that powers Claude Code (the Claude Code SDK) can power many other
   types of agents, too."
2. **Agent loop: gather context → take action → verify work → repeat.** Canonical mental
   model. The verify step is the most frequently skipped one in indie implementations.
3. **Subagents are first-class.** "Claude Agent SDK supports subagents by default." Use them
   for parallelization AND context management (isolated windows; only relevant info returned
   to orchestrator).
4. **MCP is the protocol for adding external tools.** Slack, GitHub, Drive, Asana wire in
   without OAuth/integration code. The MCP ecosystem is the dominant capability-multiplier.
5. **Three verification approaches in order of robustness:** rules-based (linting), visual
   (screenshots), LLM-as-judge ("not very robust... but for applications where any boost in
   performance is worth the cost, it can be helpful").

## Verified Quote(s)

**Location reference:** Section "Giving Claude a computer," paragraphs 1-2; Section
"Subagents" under "Gather context."

> "In other words, the agent harness that powers Claude Code (the Claude Code SDK) can power
> many other types of agents, too. To reflect this broader vision, we're renaming the Claude
> Code SDK to the Claude Agent SDK."

> "Claude Agent SDK supports subagents by default. Subagents are useful for two main reasons.
> First, they enable parallelization: you can spin up multiple subagents to work on different
> tasks simultaneously. Second, they help manage context: subagents use their own isolated
> context windows, and only send relevant information back to the orchestrator, rather than
> their full context."

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Strong Include (Rule 1) at 7.05. Foundational reference for the T5 tool-stack
analysis. Noah's existing infrastructure is built on the Claude Code / Skills / SDK trio.

**Redundancy check:** The multi-agent research post (June 2025) and the SDK post (Sep 2025)
both come from Anthropic but address different questions: one is "how we run a production
multi-agent system," the other is "how you should build one." Both kept.

**Perspective category:** Institutional
