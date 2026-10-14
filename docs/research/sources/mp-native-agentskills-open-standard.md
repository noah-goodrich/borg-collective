# Source: Agent Skills open standard (agentskills.io)

**Full citation:** Agent Skills project (originated by Anthropic). "Agent Skills Overview." https://agentskills.io/home. Live page, accessed 2026-10-13.
**URL:** https://agentskills.io/home
**Date accessed:** 2026-10-13
**Evidence level:** 4 (standards-body-style specification and client showcase)
**Research topic area:** Cross-agent portability of skills (Codex, Cursor, Gemini CLI, OpenCode, Cortex Code)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Origin owner runs the standard |
| 2 | Evidence Quality | 6/10 | Spec plus self-reported adopters |
| 3 | Currency | 9/10 | Showcase lists 2026 adopters |
| 4 | Intent | 7/10 | Ecosystem promotion |
| 5 | Bias & Objectivity | 6/10 | Adoption list is curated |
| 6 | Logic & Coherence | 9/10 | Simple, consistent model |
| 7 | Corroboration | 8/10 | Each client has own docs link |
| 8 | Intellectual Honesty | 7/10 | Invites contributions |
| 9 | Specificity | 8/10 | Folder layout, three load stages |
| 10 | Relevance | 9/10 | Portability question core |

- Authority: the format was developed by Anthropic and released as an open standard; the site is the canonical home, though governance is thin.
- Evidence Quality: it is a specification and a logo/client list; adoption is asserted, with each client linking to its own skills docs for checking.
- Currency: the client list includes 2026-era tools (for example Gemini CLI, Codex, Cursor, OpenCode, GitHub Copilot, and Snowflake Cortex Code).
- Intent: it exists to grow adoption.
- Bias: only adopters appear; there is no data on how faithfully each client implements the spec.
- Logic: the three-stage progressive disclosure model (discovery, activation, execution) is coherent and matches Anthropic's docs.
- Corroboration: Claude Code docs, the Codex docs link, and Matt Pocock's README install matrix independently confirm cross-agent use.
- Honesty: the page invites outside contributions via GitHub and Discord and does not claim parity.
- Specificity: it shows the folder layout and the load stages.
- Relevance: directly answers whether Matt's skills can leave Claude Code.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A skill is a folder with a `SKILL.md` (name, description, instructions) plus optional scripts, references, assets; agents load it by progressive disclosure.
- The format originated at Anthropic and was released as an open standard; the client showcase lists dozens of tools including Claude Code, Codex, Cursor, Gemini CLI, OpenCode, GitHub Copilot, and Snowflake Cortex Code.
- Cortex Code appears in the showcase with the description "optimized for complex data engineering, analytics, machine learning, and agent-building tasks", so Matt-style skills are in principle portable to the work CLI (compat details are carded separately by the Cortex track).
- Portability is of the file format, not of harness features: tool names, subagents, and question UIs differ per client (see the Pocock out-of-scope card).

## Verified Quote(s)

**Location reference:** Section "What are Agent Skills?" first sentence; section "Open development" first sentence; Client Showcase data entry for "Snowflake Cortex Code" in the page's embedded client list.

> Agent Skills are a lightweight, open format for extending AI agent capabilities with specialized knowledge and workflows.

> The Agent Skills format was originally developed by [Anthropic](https://www.anthropic.com/), released as an open standard, and has been adopted by a growing number of agent products.

> Cortex Code is an AI-driven intelligent agent integrated into the Snowflake platform, optimized for complex data engineering, analytics, machine learning, and agent-building tasks.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Establishes the portability baseline and places Cortex Code inside the standard.

**Redundancy check:** The Claude Code skills card covers extensions; this card covers the neutral standard and adopters.

**Perspective category:** Institutional
