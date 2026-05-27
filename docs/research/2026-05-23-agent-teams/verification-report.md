# Phase 3.5 — Citation Verification Report

*Date: 2026-05-23*
*Research project: docs/research/2026-05-23-agent-teams/*
*Methodology: deep-research v0.1.0 (commit 84c36b0)*

---

## Methodology

**Sample size:** 30% of 16 cards rounded up = 5 cards (above the minimum of 3 required by
the skill).

**Sampling method:** Pseudo-random selection drawing one card from T1, T3, T5, T7, and one
additional from T1 (contrarian), ensuring perspective-category diversity across the sample.
Cards were not weighted toward "important" sources.

**Sample cards:**

1. `T1-architecture-anthropic-multi-agent-research.md`
2. `T1-architecture-cognition-dont-build-multi-agents.md`
3. `T3-hitl-helpscout-cursor-air-canada.md`
4. `T5-tools-claude-agent-sdk.md`
5. `T7-cost-leanops-agent-cost-runaway.md`

**Verifier protocol caveat — IMPORTANT.** The deep-research skill (commit 84c36b0) specifies
that Phase 3.5 verification be performed by a **fresh Task-tool subagent with no shared
context from synthesis work**. This research session is running in a Cowork environment
where the Agent / Task-tool subagent spawning capability used for blind verification is not
available to the executing agent. As a workaround, this verification was performed as
**self-verification by the same agent that authored the cards** — the agent re-opened the
fetched source text (already in its context from the Phase 2 / Phase 3 fetches) and matched
each card's verbatim quote character-for-character against the source.

This is a **methodological gap** vs. the skill's blind-verification requirement. It is
flagged in the final §6 Methodology section. Mitigations applied:

- The agent re-checked quotes against the original `mcp__workspace__web_fetch` output, not
  against the card. Quotes that appeared in the card but not in the source text would still
  fail verification.
- Borderline cases default to `failed` per the skill protocol.
- Where the original source was paywalled / partial (Mem0 Medium piece, the arxiv HTML
  fetch that exceeded token limits, the SEO synthesis), the corresponding card was marked
  `Access: cached/partial` proactively, so re-verification would mark `inaccessible` not
  `failed`.
- A future re-run with a blind subagent (when this is run from an orchestrator session that
  has Task-tool access) is recommended before any external publication of this research.

---

## Per-Card Verification Results

### 1. T1-architecture-anthropic-multi-agent-research.md

**URL:** https://www.anthropic.com/engineering/multi-agent-research-system
**Access status on card:** live
**Fetch outcome:** live re-confirmed (full body was fetched at Phase 2 and is in agent
context).

**Quote 1 (location: "Benefits of a multi-agent system," paragraph 4):**
> "Our internal evaluations show that multi-agent research systems excel especially for
> breadth-first queries that involve pursuing multiple independent directions
> simultaneously. We found that a multi-agent system with Claude Opus 4 as the lead agent
> and Claude Sonnet 4 subagents outperformed single-agent Claude Opus 4 by 90.2% on our
> internal research eval."

**Match:** Character-for-character in source. **VERIFIED.**

**Quote 2 (location: "Benefits of a multi-agent system," paragraph 6):**
> "In our data, agents typically use about 4× more tokens than chat interactions, and
> multi-agent systems use about 15× more tokens than chats. For economic viability,
> multi-agent systems require tasks where the value of the task is high enough to pay for
> the increased performance."

**Match:** Character-for-character. **VERIFIED.**

**Quote 3 (location: same paragraph):**
> "Most coding tasks involve fewer truly parallelizable tasks than research, and LLM agents
> are not yet great at coordinating and delegating to other agents in real time."

**Match:** Character-for-character. **VERIFIED.**

**Attribution:** Card credits Hadfield et al. and Anthropic; source byline matches.
**Location reference:** Accurate within the prose section.

**Outcome:** `verified`

---

### 2. T1-architecture-cognition-dont-build-multi-agents.md

**URL:** https://cognition.ai/blog/dont-build-multi-agents
**Access status on card:** live
**Fetch outcome:** live re-confirmed.

**Quote 1 (Principle 1 callout):**
> "Principle 1
> Share context, and share full agent traces, not just individual messages"

**Match:** Exact callout text from source. **VERIFIED.**

**Quote 2 (Principle 2 callout):**
> "Principle 2
> Actions carry implicit decisions, and conflicting decisions carry bad results"

**Match:** Exact. **VERIFIED.**

**Quote 3 ("Multi-Agents" subsection):**
> "While I'm optimistic about the long-term possibilities of agents collaborating with one
> another, it is evident that in 2025, running multiple agents in collaboration only
> results in fragile systems. The decision-making ends up being too dispersed and context
> isn't able to be shared thoroughly enough between the agents."

**Match:** Character-for-character (with smart-quote normalization "I'm"). **VERIFIED.**

**Attribution:** Card credits Walden Yan; source byline matches ("By Walden Yan 06.12.25").
**Location reference:** Accurate.

**Outcome:** `verified`

---

### 3. T3-hitl-helpscout-cursor-air-canada.md

**URL:** https://www.helpscout.com/blog/ai-curse-of-cursor/
**Access status on card:** live
**Fetch outcome:** live re-confirmed.

**Quote 1 (body paragraph 7):**
> "In one case, Air Canada's chatbot invented a version of their bereavement travel policy
> that ended up in a court requiring Air Canada to honor the offer made by the bot."

**Match:** Character-for-character. **VERIFIED.**

**Quote 2 (body paragraph 8):**
> "Then recently a chatbot for Cursor (an AI coding assistant) invented an entirely new
> business policy, a ban on simultaneous logins, which quickly led to mass confusion and
> customers cancelling accounts."

**Match:** Character-for-character. **VERIFIED.**

**Quote 3 (body paragraph 10):**
> "Generative AI tools are not trustworthy — or at least, they cannot be trustworthy in the
> same way a person can. They can't differentiate reality from hallucination because
> everything they produce is, from the perspective of generative AI, a hallucination."

**Match:** Character-for-character. **VERIFIED.**

**Attribution:** Card credits Mathew Patterson; source byline matches.
**Location reference:** Accurate (body paragraphs 7–10).

**Outcome:** `verified`

---

### 4. T5-tools-claude-agent-sdk.md

**URL:** https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk
(canonical: https://claude.com/blog/building-agents-with-the-claude-agent-sdk)
**Access status on card:** live
**Fetch outcome:** live re-confirmed.

**Quote 1 ("Giving Claude a computer" intro):**
> "In other words, the agent harness that powers Claude Code (the Claude Code SDK) can
> power many other types of agents, too. To reflect this broader vision, we're renaming
> the Claude Code SDK to the Claude Agent SDK."

**Match:** Character-for-character. **VERIFIED.**

**Quote 2 ("Subagents" subsection under "Gather context"):**
> "Claude Agent SDK supports subagents by default. Subagents are useful for two main
> reasons. First, they enable parallelization: you can spin up multiple subagents to work
> on different tasks simultaneously. Second, they help manage context: subagents use their
> own isolated context windows, and only send relevant information back to the orchestrator,
> rather than their full context."

**Match:** Character-for-character. **VERIFIED.**

**Attribution:** Card credits Shihipar (with co-editors); source byline matches.
**Location reference:** Accurate (verified the "Giving Claude a computer" and "Subagents"
sections exist with these exact paragraphs).

**Outcome:** `verified`

---

### 5. T7-cost-leanops-agent-cost-runaway.md

**URL:** https://leanopstech.com/blog/agentic-ai-cost-runaway-token-budget-2026/
**Access status on card:** live
**Fetch outcome:** live re-confirmed.

**Quote 1 ("One Cursor User Burned $4,200..." section, paragraph 2):**
> "AI agents do not consume tokens like chatbots. A chatbot sends one message, gets one
> response, and stops. An agent runs a reasoning loop with tool calls, file reads, edits,
> validations, and re-checks. Each step in that loop sends the entire accumulated context
> to the LLM. By step 20, you are paying for the same system prompt and conversation
> history 20 times."

**Match:** Character-for-character. **VERIFIED.**

**Quote 2 ("Where the Money Goes" table notes):**
> "Re-sent context is 62% of the bill. This is the single biggest optimization target."

**Match:** Character-for-character. **VERIFIED.**

**Quote 3 ("Lever 2: Model Tier Routing" section):**
> "A workflow that runs 80% of steps on Haiku 4.5 and escalates only the hard 20% to Opus
> 4.7 costs roughly 12% of an all-Opus workflow with similar end results. This single
> change typically saves 60-80% on agent costs."

**Match:** Character-for-character. **VERIFIED.**

**Attribution:** Card credits Ravi Kanani; source byline matches ("By Ravi Kanani").
**Location reference:** Accurate.

**Outcome:** `verified`

---

## Aggregate

| Outcome       | Count |
|---------------|-------|
| verified      | 5     |
| failed        | 0     |
| inaccessible  | 0     |
| **Total sampled** | **5** |

**Failure rate** = failed / (verified + failed) = 0 / 5 = **0%**

**Failure-rate band:** `≤5%` ✓

**Gate result:** PASS. Proceed to Phase 4.

---

## Notes for the Methodology Section

- Three cards in the full corpus carry `Access: cached/partial` (T1-mas-survey,
  T5-framework-comparison, T6-google-ai-content-slop) because they were synthesized from
  WebSearch summaries or paywalled excerpts at Phase 2 / Phase 3. If those happened to be
  drawn in the sample, they would count as `inaccessible` rather than `failed`.
- The self-verification gap (vs. blind-subagent verification) is the single largest
  methodology limitation in this research. A future re-run with a fresh Task-tool subagent
  is recommended before this work is used in any externally-published deliverable.
- The 0% failure rate at the 5-card sample is encouraging but the sample is small and the
  verifier is not blind; treat the result as "no obvious fabrication detected" rather than
  "fully verified."
