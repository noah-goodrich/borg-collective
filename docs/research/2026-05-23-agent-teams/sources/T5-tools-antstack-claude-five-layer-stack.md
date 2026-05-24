# Source: AntStack — Claude Agents, Subagents, Agent Teams, Skills & MCP: A Developer's
Field Guide

**Full citation:** Mondal, Sourav. "Claude Agents, Subagents, Agent Teams, Skills & MCP: A
Developer's Field Guide." AntStack Blog. March 9, 2026.
**URL:** https://www.antstack.com/blog/claude-agents-subagents-agent-teams-skills-and-mcp-a-developer-s-field-guide/
**Date accessed:** 2026-05-23
**Evidence level:** 7 (Expert opinion / thought leadership — practitioner field guide)
**Research topic area:** T5 — Practical tool stack (Claude-specific composition); T1 —
Multi-agent architecture (Agent Teams)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 6/10 | AntStack is a known serverless / AI consultancy. Author Sourav Mondal is identified as a backend developer. Not Anthropic-official but maps cleanly onto Anthropic's primary docs. |
| 2 | Evidence Quality | 6/10 | No benchmarks; the field guide is taxonomic and synthesizes Anthropic's docs into a unified mental model. Code examples are concrete and reproducible. |
| 3 | Currency | 10/10 | March 9, 2026 — references Anthropic's Agent Teams (early 2026, experimental flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). |
| 4 | Intent | 6/10 | Lead-gen for AntStack consulting. Counterweight: the guide is genuinely useful and doesn't gate behind their service. |
| 5 | Bias & Objectivity | 7/10 | Doesn't push a particular orchestration philosophy; gives a decision tree and explicit "when to use" criteria. Acknowledges Agent Teams' experimental status and known limitations. |
| 6 | Logic & Coherence | 9/10 | The five-layer mental model (MCP → Skills → Agent → Subagents → Agent Teams) is the cleanest single articulation I found of the Claude stack. Decision tree at the end is directly usable. |
| 7 | Corroboration | 8/10 | Aligned with the Claude Agent SDK blog (Anthropic), the multi-agent research-system post, and Claude Code documentation. The Skills → frontmatter → progressive-disclosure framing matches Anthropic's "Equipping Agents for the Real World." |
| 8 | Intellectual Honesty | 7/10 | Explicit on common mistakes ("Using MCP when you want a Skill," "Spawning subagents for sequential tasks"). Acknowledges Agent Teams are token-expensive and experimental. |
| 9 | Specificity | 9/10 | Includes the literal YAML frontmatter format, MCP config JSON, environment variable to enable Agent Teams, five-pattern catalog with concrete examples. Reproducible. |
| 10 | Relevance | 10/10 | Direct overlap with Noah's existing stack (Claude Code, Skills, MCP, subagents). The five-layer model maps onto his borg-nanoprobe / orchestrator pattern. |

**Composite score:**
6×0.25 + 6×0.20 + 10×0.10 + 6×0.10 + 7×0.10 + 9×0.05 + 8×0.05 + 7×0.05 + 9×0.05 + 10×0.05
= 1.50 + 1.20 + 1.00 + 0.60 + 0.70 + 0.45 + 0.40 + 0.35 + 0.45 + 0.50 = **7.15**

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(The five-layer model directly mirrors how I'd recommend Noah think about the stack. Scored
5, 6, 8 harder.)

## Key Findings

1. **Five-layer Claude stack:** MCP (connectivity), Skills (expertise), Agent (core
   execution), Subagents (parallelism), Agent Teams (cross-agent collaboration). Each layer
   answers a different question.
2. **Agent and subagent file format is identical** (Markdown + YAML frontmatter in
   `.claude/agents/`); the role is determined by the call site, not the file. This means
   any agent can be promoted to orchestrator or demoted to worker without changing the
   definition.
3. **Agent Teams are experimental** (enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`).
   They allow teammates to message each other directly rather than only reporting back to a
   lead — but at significantly higher token cost.
4. **Decision rule between Subagents and Agent Teams:** "Subagents are like MapReduce
   workers... Agent teams are like a Scrum sprint." Use subagents for independent parallel
   work, Agent Teams when workers need to challenge or build on each other's outputs.
5. **Common mistakes flagged:** (a) Using MCP when you want a Skill (MCP is connectivity,
   not procedure); (b) spawning subagents for sequential tasks; (c) putting domain knowledge
   in system prompts instead of Skills (which travel across deployments); (d) jumping to
   Agent Teams before validating with subagents.
6. **Token-cost note for subagents:** "Each subagent has its own context window. Spawning 4
   subagents roughly quadruples your token usage."

## Verified Quote(s)

**Location reference:** Section "The Mental Model: Five Layers of the Claude Stack" table,
and "Subagents vs. Agent Teams" section, and "Common Mistakes to Avoid" point 1.

> "Think of building with Claude as a five-layer system, each layer composed on top of the
> one below:
> | LAYER       | Question it answers                                              |
> | MCP         | What external systems can Claude talk to?                        |
> | Skills      | How does Claude know how to do specific things well?             |
> | Agent       | Who is doing the work?                                           |
> | Subagents   | Can different parts of the work run independently in parallel?   |
> | Agent Teams | Do those parallel workers need to talk to each other?            |"

> "Subagents are like MapReduce workers; they map independently, and results are reduced at
> the end. Agent teams are like a Scrum sprint; members communicate, hand off work, and
> resolve blockers with each other."

> "Using MCP when you want a Skill, MCP connects Claude to external systems. If you're just
> trying to get Claude to do something the same way every time, that's a Skill. MCP doesn't
> encode procedure; it exposes tooling."

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Strong Include (Rule 1) at 7.15. The five-layer mental model is the
clearest synthesis of Claude's agent primitives, and it directly maps onto Noah's existing
borg/drone/nanoprobe pattern. The decision tree and anti-patterns are immediately actionable
for the recommendation section.

**Redundancy check:** Overlaps with the Claude Agent SDK blog and the multi-agent
research-system post (both Anthropic-official). AntStack's field guide adds the
unified-mental-model framing and the explicit Subagents-vs-Agent-Teams decision, which
neither Anthropic post provides cleanly.

**Perspective category:** Practitioner
