# Agent Teams for Indie GTM — How a Solo Developer Should Delegate Marketing, Sales, and Go-to-Market to Agents

*Conducted: 2026-05-22 to 2026-05-23*
*Methodology: deep-research v0.1.0 (commit 84c36b0, with Phase 3.5 citation verification)*
*Researcher: Claude (auto-approved by Noah Goodrich)*

---

## 1. Recommendations

These are ordered by urgency. Each starts with a verb and points to the analysis section that supports it.

1. **Adopt the orchestrator-with-isolated-subagents pattern, not "agent teams that talk to each other."** For GTM workflows where each step is mostly independent (write a blog, draft an outbound email, draft a Reddit response), Anthropic's orchestrator-worker pattern is the production-proven default. The "agent teams" variant where workers message each other directly is still experimental in Claude Code as of March 2026, costs significantly more in tokens, and is what Cognition's "Don't Build Multi-Agents" argues against. See §4.1 and §4.2.

2. **Delegate-today list (start this quarter):** SEO blog drafting (with human review), email-sequence drafting, social-post drafting, Reddit/HN/Discord monitoring (without auto-posting), lead enrichment, top-of-funnel "AI SDR" outreach to broad ICPs ONLY for reveal/ingle/troth audiences where volume matters more than precision, and FAQ/support triage for tier-1 questions. See §4.3.

3. **Hold-back list (keep human-driven through 2026):** strategic positioning, pricing, brand voice exceptions, anything sent to a single named high-value prospect, customer escalations beyond tier-1, sales calls, legal/compliance copy, anything that would create FTC liability (reviews, testimonials, social-media bot accounts). See §4.4.

4. **Build the stack on Anthropic's primitives.** Claude Agent SDK + Skills + MCP + Subagents. Avoid CrewAI / AutoGen / LangGraph unless you hit a specific limitation — AutoGen is effectively in maintenance mode, CrewAI is best for "assemble a team" mental models that don't match the orchestrator-worker pattern you actually want, and LangGraph's main advantage (LangSmith observability + checkpointing) duplicates what Claude Agent SDK provides. See §4.5.

5. **Add a memory layer.** The Cairn knowledge graph Noah already has covers session-state well; pair it with Mem0's OpenMemory MCP (local-first, works with Claude Desktop and Cursor) for cross-session user/brand/account memory. The "procedural memory" type — storing learned workflows, tool-use habits — is the missing piece in most indie stacks today. See §4.6.

6. **Budget $400-$700/month per product for the GTM agent stack, with a hard $1,000/month cap.** Without caching, tier routing, and budget caps, expect $1,500-$3,000/month. With them, $400-$700. Set hard per-day caps ($50/day soft alert, $100/day hard cutoff per workflow). See §4.7.

7. **Define brand voice in a Skill, not in a system prompt.** Skills travel across Claude Desktop / Claude Code / API / Cowork; system prompts don't. Drift is the single most common quality failure in scaled AI content; the fix is a `brand-voice` Skill loaded as the first message of every content workflow plus a separate `voice-classifier` LLM-judge step that scores drafts before they ship. See §4.8.

8. **Build a "boundary skill" and a "compliance skill" before scaling.** The FTC's October 2024 final rule prohibits AI-generated reviews, fake social-media-influence indicators, and undisclosed insider testimonials with penalties up to $51,744 per violation. Encode these as a hard `compliance-guardrails` Skill that runs as a pre-publish gate. See §4.9.

9. **Don't replace yourself yet — replace the lowest-judgment 80%.** The empirical pattern from Cemri et al. (MASFT failures), Cognition (don't build multi-agents), and the AI-SDR churn data (50-70% within a year for autonomous SDRs) all converge: full autonomy is what fails. Bounded delegation with a clear human approval gate is what works. See §4.10.

10. **Three immediate next moves for reveal (specifically):**
    - **This week:** ship a `reveal-brand-voice` Skill and a `reveal-compliance` Skill in `~/.claude/skills/`. Use Skills format (not project-local) so they work in Claude Desktop, Cowork, and Claude Code.
    - **Next 2 weeks:** stand up one workflow end-to-end — pick blog drafting as the lowest stakes (low damage if wrong, high formulaic) and instrument it with the gather-context → take-action → verify loop. Use Skills for voice + compliance, Cairn for past-post memory, and a single Sonnet-tier draft + Opus-tier review pass. Budget $50/month for this workflow alone.
    - **Within 30 days:** add a second workflow — Reddit/HN monitoring (NOT posting). Pull mention signals via an MCP server, route them through a `community-triage` Skill that decides "ignore / Noah responds / draft a response for Noah to send," then deliver summaries to Noah's daily briefing. This adds zero spam risk and proves the monitor-then-decide pattern before you trust anything outbound. See §4.11.

---

## 2. Summary

**What the research asked.** Noah is shipping consumer products (reveal, troth, ingle) plus infrastructure (borg, cairn) as a solo developer. He wants to delegate marketing, sales, and GTM operations to agent teams so he can free up dozens of hours per month. Goal: ~30× leverage on his ability to ship products to market. The research asked which agent team structure to adopt, which GTM functions are ready to delegate, where humans must stay involved, what the realistic monthly cost looks like, and what the first three moves should be for reveal specifically.

**The 5 most important findings.**

1. **The architecture debate is real but the answer for indie GTM is settled.** Anthropic's data (90.2% improvement on internal research eval with orchestrator + 3-5 parallel subagents) and Cognition's contrarian "don't build multi-agents" essay are both right — they're describing different workloads. Anthropic's pattern wins for "breadth-first parallel research" tasks like "monitor 20 subreddits, summarize." Cognition is right that "agents talking to each other to coordinate" is fragile. For GTM, you want Anthropic's pattern: one orchestrator, many isolated subagents, no inter-agent chatter.

2. **GTM functions ready for delegation today (with human review):** SEO content drafting, email sequence drafting, social drafts, Reddit / HN / Discord monitoring, lead enrichment, top-of-funnel high-volume outbound to broad ICPs, FAQ / tier-1 support. Functions that still fail when fully delegated: customer escalations, sales calls, anything sent to named high-value prospects, strategic positioning, brand voice exceptions, reviews and testimonials (FTC-illegal), regulated compliance copy. The 11x.ai story (70-80% customer churn, fabricated customer claims) is the canonical case study.

3. **Where humans MUST stay.** Across all the practitioner literature reviewed — Help Scout on the Air Canada and Cursor incidents, Gutenberg on human-led AI marketing, Mean CEO on solo founders, the FTC rule itself — the consensus is sharp: humans own strategy, creative judgment, final decisions, and any output that touches a named external party. AI handles execution scale. "AI raises the floor but does not raise the ceiling" (Lemkin via Salesmotion).

4. **Cost is wildly variable; discipline is the gating variable.** LeanOps' 30-team audit shows agent costs per developer / per workflow range from $80/month (p10) to $4,200+/month (p99), a 20-50× spread. The four levers that cut costs 50-70% are universally agreed: prompt caching, model tier routing, context pruning, hard per-user budget caps. Without them, an indie operator running a single GTM workflow can hit $1,500-$3,000/month. With them, $400-$700.

5. **The biggest under-discussed risk is "agent team complexity overhead."** Cemri et al.'s MASFT taxonomy (14 failure modes across specification / inter-agent misalignment / task verification) shows that open-source multi-agent frameworks fail 41-86.7% of tasks. Even best-effort prompt-engineering interventions only improved correctness by 14%. The implication for Noah: every additional agent in the team adds coordination overhead; the leverage curve flattens fast.

**Where experts disagree.** Anthropic publicly bets on multi-agent orchestrator-worker architectures (Claude Research feature). Cognition publicly bets on single-threaded linear agents with context compression. Both companies ship production agent systems. The reconciliation: multi-agent works for breadth-first parallel work with clean task boundaries; single-threaded works for dependency-heavy work. GTM has both; orchestrator + isolated subagents (Anthropic's pattern) is the better fit for the breadth-first GTM tasks (monitoring, content production, outreach drafting), and single-threaded with HITL is the better fit for the dependency-heavy tasks (a full campaign launch).

**What surprised me.** The cost-spread data. A 20-50× per-workflow cost spread between disciplined and undisciplined operators is much larger than I expected. It changes the question from "how much will this cost?" to "have you set the caps?" Caps are the lever.

**The one thing to remember.** For a solo indie, the win is not "build a multi-agent team." The win is "delegate the lowest-judgment 80% of GTM tasks, keep humans on the highest-judgment 20%, and instrument everything so cost and quality don't drift." The agent stack is the cheap part. The discipline (Skills for brand voice and compliance, hard budget caps, human approval gates) is what determines whether this works.

---

## 3. The Indie GTM Agent Stack — A Four-Tier Delegation Framework

A framework emerged from the research: a four-tier model for deciding which GTM tasks an indie founder should hand to an agent, with concrete operational rules per tier.

**Sources backing this framework:** Anthropic multi-agent research-system post [Score: 7.95 | Level 5]; Mean-CEO solo-founder stack [6.60 | Level 7]; LeanOps cost runaway audit [6.85 | Level 5]; Salesmotion AI SDR honest-comparison [6.90 | Level 7]; Gutenberg human-led-AI marketing [5.55 | Level 7]; Help Scout Cursor/Air Canada [7.20 | Level 7]; FTC final rule via Sidley [8.25 | Level 4]. Composite-weighted, the framework leans on the orchestrator-worker architecture (Anthropic), the cost-lever discipline (LeanOps), and the delegation-readiness assessment (Salesmotion / Mean CEO / Gutenberg).

### Tier 0 — Full Delegation (Agent acts, human reviews on a sampled basis)

**Tasks:** lead enrichment, SEO keyword research, competitive monitoring, content topic ideation, social-media post scheduling (not authoring), analytics report generation, internal documentation drafts.

**Operational rules:**
- Single subagent, no orchestrator. Cheap (Haiku-tier or equivalent).
- Output reviewed by sampling, not per-item.
- Budget: $20-$80/month per workflow.

**Failure tolerance:** high — these are internal-facing or scheduling-mechanical tasks.

### Tier 1 — Agent Drafts, Human Approves Each Output

**Tasks:** blog post drafting, email sequence drafting, social post drafting, Reddit response drafting, FAQ / tier-1 support response drafting, outbound email personalization drafts.

**Operational rules:**
- Orchestrator + 1-3 isolated subagents (research, draft, voice-check / compliance-check).
- Brand voice loaded as a Skill. Compliance loaded as a Skill.
- Human must explicitly approve each output before it ships externally.
- Budget: $100-$300/month per workflow.

**Failure tolerance:** medium — the human approval gate catches drift before it reaches customers.

### Tier 2 — Agent Suggests, Human Drives the Decision

**Tasks:** sales call follow-up suggestions, customer escalation triage, pricing experiments, churn risk flagging, partnership outreach lists, conference / podcast pitch lists.

**Operational rules:**
- Agent produces a recommendation with supporting context (data, prior interactions, named evidence).
- Noah makes the actual decision and writes the customer-facing copy.
- Agent is a research / synthesis layer, never a publishing layer.
- Budget: $50-$150/month per workflow.

**Failure tolerance:** low — but the agent never publishes, so the worst case is wasted suggestion time, not customer-visible failure.

### Tier 3 — Human-Only (Do Not Delegate)

**Tasks:** strategic positioning, pricing strategy, brand voice exceptions, customer escalations beyond tier-1, sales calls, legal / compliance copy, reviews and testimonials (FTC-illegal to generate), any output sent to a single named high-value prospect, anything where founder accountability is the load-bearing element.

**Operational rules:**
- No agent involvement except as research / context retrieval.
- These are exactly the tasks where, per Mean CEO and Gutenberg, the founder cannot delegate because the decision requires "skin in the game."

**Failure tolerance:** zero. These are the high-stakes calls.

### How to use the framework

For each GTM task in your week, classify into Tier 0-3 using two questions: (a) how formulaic is this task? (b) what's the damage if the output is subtly wrong? High-formulaic + low-damage → Tier 0. Complex judgment + high damage → Tier 3. This is essentially the Mean-CEO triage rule, formalized into a four-tier model.

**Anchoring to Noah's products:** for reveal specifically, content drafting and Reddit monitoring are Tier 1; lead enrichment and analytics reports are Tier 0; user research synthesis and pricing experiments are Tier 2; positioning and "should I ship feature X" are Tier 3.

### Limits of the framework

- It doesn't capture which model to use within each tier (separate decision — see §4.6).
- It assumes Noah is the sole operator. If Noah hires a part-time GTM person, Tier 2 work can shift to them and free Tier 3 cycles for Noah.
- The boundary between Tier 1 and Tier 2 will move as agent quality improves. Today blog drafts are firmly Tier 1; in a year, blog drafts to a non-paying audience may move to Tier 0.

---

## 4. Analysis

### 4.1. Architecture — orchestrator-worker is the right pattern for breadth-first GTM tasks

**Research question:** What multi-agent architecture pattern (orchestrator, hierarchical, specialist team, hub-and-spoke, mesh) best fits a solo indie GTM context?

**What the evidence says.** The orchestrator-worker pattern (one lead agent decomposes a task and spawns parallel subagents with isolated context windows) is the dominant published pattern for production multi-agent systems as of mid-2026. Anthropic's Claude Research feature uses it and reports 90.2% improvement over single-agent Opus on breadth-first research tasks [Anthropic multi-agent research, Score: 7.95 | Level 5]. Token usage "explains 80% of the variance" in performance — meaning the leverage comes from the parallel context expansion, not from clever coordination. Three to five parallel subagents per orchestrator with explicit task boundaries is the practical sweet spot.

**Where sources agree.** Anthropic, AntStack (five-layer Claude stack guide), and the Tran et al. survey of MAS collaboration mechanisms all converge on the orchestrator-worker pattern as the most consistently successful structure for breadth-first work. The collaboration-mechanism taxonomy (actors / types / structures / strategies / coordination protocols) maps cleanly onto Anthropic's specific instantiation [Tran et al., 7.75 | Level 3].

**Where sources disagree.** Cognition argues forcefully against multi-agent architectures in its widely-cited "Don't Build Multi-Agents" post [Score: 6.90 | Level 7]. The argument is sharp: parallel subagents make "implicit decisions" that conflict with each other, producing inconsistent results when reassembled. The Flappy Bird example (subagent 1 builds a Super Mario background, subagent 2 builds a bird in a different visual style, the orchestrator can't reconcile) generalizes — multi-agent fails when subtasks have hidden dependencies. Cognition's contrarian recommendation: single-threaded linear agents with explicit context-compression steps.

The reconciliation is empirical, not philosophical. Cemri et al.'s MASFT paper [8.65 | Level 3] studied five open-source multi-agent frameworks (ChatDev, AG2/MetaGPT, etc.) and found failure rates of 41-86.7% (ChatDev's correctness can be as low as 25%). Best-effort prompt-engineering interventions only improved correctness by 14% — not enough for production. Multi-agent fails when the framework is naive about coordination, OR when the workload has dependencies the architecture assumed away.

For breadth-first GTM tasks (monitoring 20 subreddits, drafting 10 blog variants, researching 100 leads) — Anthropic's pattern wins. For dependency-heavy GTM tasks (a full campaign launch requiring research → strategy → copy → design → distribution) — Cognition's single-threaded pattern, with the orchestrator promoting subagents only for genuinely independent steps, wins.

**What's missing.** No peer-reviewed evaluation of multi-agent architectures *specifically for GTM* exists in the literature surveyed. The MASFT work studies software-engineering and reasoning tasks; the Anthropic post is research-task-specific; the Cognition post is coding-task-specific. The applicability transfer is supported by the architecture taxonomy (Tran et al.) but not by direct GTM evidence.

**Institutional vs ground-truth delta.** Anthropic / OpenAI both market multi-agent orchestration as a flagship capability; indie operators in the boots-on-ground literature (Mean CEO, AntStack's field guide) consistently warn that the marginal benefit drops fast beyond 3-5 subagents and that "agent teams that talk to each other" remains experimental and token-expensive [AntStack, 7.15 | Level 7].

### 4.2. The "agent teams that talk to each other" question

**Research question:** Should Noah use Claude Code's experimental "Agent Teams" feature, or stick with subagents that report back to the orchestrator?

**What the evidence says.** As of March 2026, Anthropic's Agent Teams are explicitly flagged experimental (enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) [AntStack, 7.15 | Level 7]. They allow teammates to message each other directly rather than only reporting to a lead — useful for tasks where workers need to challenge or build on each other's outputs (e.g., API designer + reviewer + test writer). The trade-off is "significantly higher token cost" plus "known limitations around session resumption and task coordination."

**Where sources agree.** AntStack, Cognition, and Cemri et al. all converge: start with subagents (independent parallel), graduate to inter-agent communication only when the workload genuinely demands it. The mantra from AntStack: "Subagents are like MapReduce workers; they map independently, and results are reduced at the end. Agent teams are like a Scrum sprint; members communicate, hand off work, and resolve blockers with each other."

**Where sources disagree.** Salesforce / vendor literature on Agent Teams (not deeply sourced in this research because it skews into press-release territory) leans more optimistic. The independent practitioner view (AntStack, Cognition implicit, Cemri's MASFT findings) is more cautious.

**What's missing.** Production evals of Anthropic's Agent Teams feature in non-coding domains. The Agent SDK release post (September 2025) describes the SDK and Skills but doesn't validate Agent Teams empirically [Anthropic Agent SDK, 7.05 | Level 7].

**Institutional vs ground-truth.** Anthropic markets Agent Teams as the future direction; practitioners say "validate with subagents first." For indie GTM, the practitioner view wins on cost alone — Agent Teams' token overhead is hard to justify at indie scale.

### 4.3. GTM functions ready for delegation today

**Research question:** Which specific GTM functions are mature enough for agentic execution right now?

**What the evidence says.** The practitioner literature converges on a delegation-readiness ordering:

- **Mature / ready:** SEO content drafting (with human review), email sequence drafting, social post drafting, lead enrichment, top-of-funnel outbound to broad ICPs, Reddit/HN/Discord *monitoring* (not posting), tier-1 FAQ responses, internal analytics reports [Mean CEO, 6.60; Salesmotion, 6.90].
- **Borderline:** outbound email at named-prospect granularity, in-thread Reddit/HN responses, customer onboarding flows, churn-risk flagging [Salesmotion's "intelligence layer + human or AI execution" framing].
- **Not yet mature:** sales calls, escalated customer support, content authoring without human review, reviews/testimonials (FTC-illegal regardless of quality), regulated compliance copy [Help Scout, 7.20; Sidley/FTC, 8.25].

**Where sources agree.** Across Mean CEO, Salesmotion, Gutenberg, and Help Scout, the consensus is that AI handles "execution at scale" well — high-volume, low-judgment, formulaic tasks. AI handles "strategic decisions" badly. The dividing line is the formulaic-ness × damage-if-wrong axis.

**Where sources disagree.** Jason Lemkin (via Salesmotion) replaced his entire GTM team with 20 AI agents managed by 1.2 humans, sending 70,000 emails vs. 7,000 from the human team — and described the result as "better than a mid-pack AE or SDR, but not better than top performers." Sahil Mansuri (Bravado) argues the opposite — that AI makes top salespeople more valuable, not less. The reconciliation: Lemkin and Mansuri agree on the mechanism (AI raises floor, not ceiling); they differ on the policy implication. For an indie like Noah without high-value enterprise deals to close, raising the floor is the whole game.

**What's missing.** Hard data on agent-assisted indie GTM specifically (most data is B2B-enterprise or VC-backed-startup). The Mean CEO piece is the closest analog but is itself a thought-leadership essay [Score 6.60].

**Institutional vs ground-truth.** Vendor marketing (11x.ai, Artisan) promised full SDR replacement; practitioner reality (50-70% churn within a year, the 11x scandal with 70-80% customer churn and fabricated claims) reset expectations. The honest middle ground — "intelligence layer + human or AI execution" — is where the operating models that survive have landed [Salesmotion, 6.90].

### 4.4. Where humans must stay involved

**Research question:** Where do humans have to stay involved, and what's the evidence?

**What the evidence says.** Three convergent classes of "human-only" work:

1. **Strategic decisions** — positioning, pricing, market selection, customer prioritization. Mean CEO: "AI agents cannot validate your market, choose your pricing, or decide which customer to fire — human judgment remains the irreplaceable core."
2. **Customer-trust moments** — escalations, sales conversations, partnership outreach, anything sent to a named high-value individual. Help Scout's case studies of Air Canada (bereavement-policy fabrication, court ordered Air Canada to honor the hallucinated policy) and Cursor (fabricated simultaneous-login policy, mass cancellations) demonstrate that "first filter" framing of AI is misleading — for customers, the AI's response is often the entire interaction with the company.
3. **Compliance and brand voice** — FTC final rule (October 2024) prohibits AI-generated reviews and fake social-media-influence indicators with penalties up to $51,744 per violation. Brand voice drift across long content is well-documented; 68% of consumers will abandon a brand whose tone shifts noticeably.

**Where sources agree.** Help Scout, Gutenberg, FTC (via Sidley), and Mean CEO all converge on the same boundary: humans own meaning, taste, accountability, and any output attached to a named external party.

**Where sources disagree.** Gutenberg's pod model proposes a structural fix (humans embedded in cross-functional pods with AI execution capacity) as an alternative to per-decision approval gates. The structural-vs-process question is open; for a solo founder both collapse into "Noah is in the loop on this decision."

**What's missing.** Empirical data on whether disclosed AI responses (the fix Cursor adopted post-incident) actually preserve trust. Anecdotally yes; no longitudinal evidence.

**Institutional vs ground-truth.** Vendor messaging often blurs the line — Decagon's "Agent Operating Procedures" pitch implies more autonomy than the production reality supports. The practitioner literature (Help Scout, AntStack, Mean CEO) is more conservative than vendor marketing.

### 4.5. Tool stack — what to build on

**Research question:** Which production-ready frameworks compose with Noah's existing infrastructure (Claude Code, Claude Desktop, Cowork plugins, MCP, Cairn)?

**What the evidence says.** For Noah's specific situation, the Anthropic stack (Claude Agent SDK + Skills + MCP + Subagents) is the lowest-friction choice. It composes natively with Cowork and Claude Code; Skills travel across Claude Desktop, Cowork, API, and multiple agents (where system prompts don't); MCP gives interoperability with the broader tool ecosystem [Anthropic Agent SDK, 7.05 | Level 7; AntStack, 7.15 | Level 7].

**The framework comparison.** Among the third-party alternatives:
- **LangGraph** — production-readiness leader (LangSmith observability, checkpointing, streaming). Best for stateful long-running workflows. Adds dependency surface area.
- **CrewAI** — best for role-based "assemble a team" mental models. Lowest barrier to entry. Adds an abstraction layer over what Claude Code already provides.
- **AutoGen** — "effectively in maintenance mode" per multiple 2026 sources. Don't pick it for new projects.

[Anubhav framework comparison, 6.40 | Level 7]

**Where sources agree.** For a Claude-native shop, the Anthropic stack is the right default. Add a third-party framework only when you hit a specific limitation.

**Where sources disagree.** Production-team write-ups sometimes recommend LangGraph for the observability story even on Claude-native stacks. The trade-off is dependency complexity vs. observability completeness.

**What's missing.** A side-by-side eval of Claude Agent SDK + native subagents vs. LangGraph orchestrating Claude in a typical GTM workflow. Most public comparisons are coding-task or general-reasoning benchmarks.

**Institutional vs ground-truth.** Vendor positioning is muddled because every framework claims to do everything. The practitioner consensus (AntStack, the Anubhav comparison) is "frameworks are not interchangeable; pick the operational model that fits your problem."

### 4.6. The memory layer

**Research question:** What memory infrastructure should layer onto the agent stack?

**What the evidence says.** Three memory types matter for GTM agents:

1. **Episodic** (what happened — interactions, decisions made, content shipped)
2. **Semantic** (what is known — brand voice, ICP, product facts)
3. **Procedural** (how things should be done — workflow patterns, tool-use habits, review conventions)

[Mem0, 6.95 | Level 5]

Cairn (Noah's existing knowledge graph) covers episodic well — it stores decisions, reasoning, patterns from sessions. The semantic layer can live in Skills (brand voice, product facts as `~/.claude/skills/brand-voice/`, `~/.claude/skills/reveal-product/`). Procedural memory is the gap — agents need to learn "how Noah does Reddit responses" over time, and neither Cairn nor Skills handle this cleanly.

The pragmatic addition: Mem0's OpenMemory MCP for local-first cross-session memory. Works with Claude Desktop, Cursor, Windsurf, VS Code — all tools Noah already uses. Setup time ~5 minutes. No cloud dependency. Stores procedural memory across sessions.

**Where sources agree.** Memory as a separate architectural component (not just longer context) is now standard. Token efficiency matters: a system needing 26K tokens per query "is not production-viable" — Mem0's benchmark hits 92.5 on LoCoMo at ~7K tokens.

**Where sources disagree.** Letta argues for OS-style memory tiers (core / archival / recall); Zep argues for temporal knowledge graphs. The space is converging on multi-signal retrieval (semantic + keyword + entity) regardless of the wrapper.

**What's missing.** A first-class procedural-memory implementation in any of the major frameworks. Mem0 acknowledges procedural memory as "an area where Mem0's architecture supports the concept, but the tooling for managing procedural memory specifically is still early-stage."

### 4.7. Cost — the discipline question

**Research question:** What does running a continuous agentic GTM team for one indie product cost per month?

**What the evidence says.** LeanOps' 30-team audit found cost-per-developer distributions of $80 (p10), $480 (p50), $1,650 (p90), $4,200+ (p99) per month. The 20-50× spread is dominated by discipline, not usage volume [LeanOps, 6.85 | Level 5].

**Four cost levers that work (consistently 50-70% savings):**
1. **Prompt caching** for system prompts and tool definitions (~88% savings on system-prompt cost across a 50-step loop).
2. **Model tier routing** — Haiku for routine, Sonnet for quality, Opus for hard reasoning (60-80% savings on agent costs).
3. **Aggressive context pruning** — sliding window, tool result truncation, step compression every 10 steps.
4. **Hard per-user budget caps** — $50/day soft alert, $100/day hard cutoff, $1,000/month monthly ceiling.

**Best/worst/expected for a single indie product GTM stack:**
- **Best (disciplined):** $400-$700/month covering content + monitoring + outreach drafts + enrichment + support tier-1. Aligns with Mean-CEO's $300-$500/month figure.
- **Expected (medium discipline):** $700-$1,500/month.
- **Worst (no caps):** $1,500-$3,000/month and rising, with $4,200+ weekend disasters possible.

**Where sources agree.** The agent cost curve is unstable without discipline. Every source that ran an audit reports the same pattern: 62% of bills go to re-sent context, model overuse is the dominant secondary cost, and caps are the only proven prevention.

**Where sources disagree.** Mean CEO and LeanOps differ on the floor ($300-$500/month vs. $400-$700) but the difference is workflow count (Mean CEO's $300 covers code + content + support + design + automation — broader than what a single GTM workflow includes).

**What's missing.** Indie-specific cost benchmarks at lower volume. Most cost reports are B2B / mid-market.

### 4.8. Brand voice — the under-specified risk

**Research question:** How does brand voice drift, and what guards against it?

**What the evidence says.** "AI gradually shifts your voice toward the internet average, using phrases and styles that lack personality" — the dominant failure pattern when content is generated at scale without brand-voice constraints. 68% of consumers will abandon a brand whose tone changes noticeably. Drift happens within a single long output (opening paragraphs match brand, conclusion sounds generic) and across sessions (the agent doesn't remember its own past style choices).

**The fix that practitioners converge on** [Gutenberg, 5.55; brand-voice synthesis from search]:
1. **Brand voice as documented structured data** (not free-text guidance). 5-10 top-performing examples + voice-attribute fields + forbidden terms + approved messaging.
2. **AI voice classifier as a pre-publish gate.** An LLM-judge step that scores drafts against the brand-voice corpus before they ship. Practitioner reports cite >90% tone-drift catch rates with proper training.
3. **Human editor on a sampling basis** for the highest-stakes outputs.
4. **Quarterly drift audits** — track editorial revision rates; if editors consistently rewrite the same types of issues, the brand-voice prompts need adjustment.

**Where sources agree.** Three layers of validation (classifier + rules + human) is the practitioner consensus. Documentation as structured data, not narrative.

**Where sources disagree.** Tooling. Contentstack, AirOps, Optimizely, Stridec each propose slightly different schemas. None have won.

**What's missing.** Open-source brand-voice classifier evals at indie scale.

### 4.9. Compliance — the hard floor

**Research question:** What are the legal limits on AI-driven GTM?

**What the evidence says.** The FTC final rule effective October 21, 2024 prohibits:
- Fake or AI-generated consumer reviews and testimonials
- Buying positive or negative reviews
- Fake indicators of social-media influence (bots, fake accounts, hijacked accounts)
- Undisclosed insider reviews (officers, employees, immediate relatives)
- Company-controlled "independent" review sites
- Review suppression

Penalties up to $51,744 per violation. The rule explicitly names AI as a target: "AI tools make it easier for bad actors to pollute the review ecosystem by generating, quickly and cheaply, large numbers of realistic but fake reviews." [Sidley, 8.25 | Level 4].

Air Canada's defense that "the chatbot was a separate legal entity responsible for its own answers" was rejected by the court. **Companies are liable for what their AI says.**

Platform-specific compliance (Reddit, HN, X, LinkedIn) adds another layer:
- Reddit's 90/10 rule (90% genuine value, 10% promotional) is enforced via shadowbans (largely automated as of 2026, triggered by rapid posting, link patterns, account-age vs. activity mismatch, IP association) [ReplyAgent, 5.75 | Level 7].
- AI-generated comments at scale, even "natural" ones, are increasingly classified as spam by community moderators.

Google's May 2025 guidance on scaled content abuse: AI authorship isn't itself penalized, but "using generative AI tools to create many pages without adding value for users may violate our spam policy on scaled content abuse." Sites relying solely on AI content lost 17% of traffic and dropped 8 positions on average; sites with AI + human oversight lost only 6% and dropped 3 positions [SEO synthesis, 6.55 | Level 5].

**Where sources agree.** The legal and platform-norm floor is consistent: AI execution is fine; AI substitution for human accountability is not.

**What's missing.** Litigation specifically targeting AI-generated outbound (cold email) under CAN-SPAM. The FTC rule covers reviews and testimonials but is silent on outbound sales copy.

### 4.10. When does adding agents stop adding leverage?

**Research question:** When does the agent-stack-leverage curve flatten or invert?

**What the evidence says.** Anthropic's data suggests sub-linear leverage past ~10 subagents per orchestrator. Cemri et al.'s MASFT taxonomy shows coordination overhead dominates at scale — most failure modes are inter-agent misalignment, not individual-agent limitations. The AgentOps emerging role (one of several 2026 "Agent Supervisor / Agent QA Lead" job titles) suggests enterprises are hiring humans to manage agent fleets, signaling that the coordination overhead became real enough to warrant headcount.

**For a solo indie:** The curve flattens earlier. Mean CEO's estimate of "two weeks per agent" to train to reliable quality means even adding a third or fourth workflow takes a month-plus of upfront investment. The first agent saves 10x more hours than the fifth.

**The first human hire signal** (per Mean CEO, Salesmotion, and the AgentOps trend) is when:
- The founder is spending more time supervising agents than the agents are saving them.
- Two or more workflows are drifting on quality (brand voice, compliance) faster than the founder can correct.
- A specific high-stakes function (customer success, partnerships, sales) is bottlenecked on founder time AND can't be safely delegated to an agent.

The most common first hire is **a fractional human who owns Tier 2-3 work** (strategy, customer relationships, brand exceptions) — not someone to "manage the agents." Agent management is more accurately framed as "build better Skills" rather than "hire an agent manager."

**Where sources agree.** The leverage curve flattens; the question is when. For indies the answer is "earlier than VC-funded startups" because the founder has less capacity to absorb coordination overhead.

**Where sources disagree.** Some indie practitioners (Pieter Levels, Ben Broca) report sustained leverage with very small or zero human teams. The reconciliation: their businesses are narrow enough (single-product, narrow ICP) that the coordination overhead stays manageable.

### 4.11. Three immediate moves for reveal specifically

**Research question:** What are the first three concrete actions to set up agentic GTM for reveal?

**Synthesized recommendation:**

1. **This week — ship two Skills:**
   - `~/.claude/skills/reveal-brand-voice/` — structured voice attributes, 5-10 top-performing examples (existing reveal copy, Noah's tone), forbidden terms, approved messaging hooks. Loaded as a Skill so it travels across Claude Desktop, Cowork, and Claude Code.
   - `~/.claude/skills/reveal-compliance/` — FTC review rule, Reddit 90/10, Google scaled content abuse, basic GDPR for EU users. Runs as a pre-publish gate.

2. **Next 2 weeks — one workflow end-to-end:**
   - Pick blog drafting (lowest stakes — Tier 1 in the framework).
   - Orchestrator: a Claude Agent SDK agent that gathers topic input from Noah, pulls past reveal posts from Cairn for context, spawns 2 subagents (one for research, one for draft), runs the voice-check Skill, runs the compliance Skill, and outputs a draft for Noah to approve.
   - Budget: $50/month, hard cap.
   - Success metric: a publishable draft Noah edits in <15 min, twice per week.

3. **Within 30 days — add a monitor-then-decide workflow:**
   - Reddit / HN monitoring (NOT posting). Pull mentions of reveal / its category via an MCP server (or a polling subagent). Route through a `community-triage` Skill that classifies each mention into "ignore / Noah responds / draft response for Noah to send." Deliver daily summaries to Noah's borg morning briefing.
   - Zero posting risk; proves the monitor-then-decide pattern works before extending it to outbound.
   - Budget: $30-$60/month.

**Why these three specifically.** Each one delegates a Tier 0 or Tier 1 function (high formulaic-ness, low damage if subtly wrong). None of them touches Tier 3 work (positioning, pricing). The Skills built in step 1 are infrastructure that every subsequent workflow reuses, so the marginal cost of workflow #3 is much lower than workflow #1.

---

## 5. Research — Full Findings by Topic Area

### T1. Multi-agent architecture

**Key finding 1.** Orchestrator-worker pattern is the dominant published architecture for production multi-agent systems in 2025-2026. Anthropic reports 90.2% improvement over single-agent Opus on internal research evals using this pattern, with token usage explaining 80% of performance variance — implying that the leverage is the parallel context expansion. [Anthropic multi-agent research-system, 7.95 | Level 5: Practitioner case study with data]

**Key finding 2.** 3-5 parallel subagents per orchestrator is the empirical sweet spot for breadth-first tasks. Anthropic's explicit scaling rules: 1 agent for simple fact-finding, 2-4 subagents for direct comparisons, 10+ for complex research. [Anthropic, 7.95 | Level 5]

**Key finding 3.** Multi-agent fails when subtasks have hidden dependencies. The Cognition "Flappy Bird" example: subagent 1 builds a Super Mario background, subagent 2 builds a bird in a different visual style — orchestrator can't reconcile. Generalizes to any multi-step workflow with implicit shared state. [Cognition "Don't Build Multi-Agents," 6.90 | Level 7: Expert opinion]

**Key finding 4.** Five open-source MAS frameworks studied by Cemri et al. fail 41-86.7% of tasks. ChatDev correctness can be as low as 25%. Best-effort prompt-engineering interventions yielded only +14% on ChatDev — still far below deployment-ready. 14 failure modes in 3 categories: specification, inter-agent misalignment, task verification. [Cemri et al. MASFT, 8.65 | Level 3: Large-scale observational]

**Key finding 5.** Five-dimensional taxonomy for MAS collaboration: actors / types (cooperation / competition / coopetition) / structures (peer-to-peer / centralized / distributed) / strategies (role-based / model-based) / coordination protocols. No single structure dominates; domain fit matters more than topology purity. [Tran et al. MAS collaboration survey, 7.75 | Level 3]

### T2. GTM functions ready for delegation

**Key finding 6.** Three categories of AI SDR tools (autonomous agents / copilots / intelligence layers); only the intelligence layer + human or AI execution approach has sustainable ROI for B2B sales. Autonomous SDRs have 50-70% churn within a year; only 2% of companies sustain them. [Salesmotion AI SDR comparison, 6.90 | Level 7]

**Key finding 7.** The 11x.ai case study: $74M raised, customer churn 70-80%, fabricated customer claims (ZoomInfo legal threat, Airtable denial). Internal numbers allegedly massaged. Performance "significantly worse than SDR employees" per ZoomInfo trial. [Salesmotion, 6.90 | Level 7; corroborated by TechCrunch March 2025 reporting]

**Key finding 8.** Lemkin's SaaStr experiment: 20 AI agents managed by 1.2 humans, sent 70K emails vs 7K from human team. Result: "better than a mid-pack AE or SDR, but not better than top performers." Generalizes: "AI raises the floor but does not raise the ceiling." [Salesmotion citing Lemkin, 6.90 | Level 7]

**Key finding 9.** Solo founder agent stack ($300-$500/mo) replaces functions previously requiring $80,000-$120,000/mo human payroll. 36.3% of new ventures in 2026 are solo-founded. The constraint shifted from "can I build the team?" to "how long can I extend runway by not hiring?" [Mean CEO solo founder stack, 6.60 | Level 7]

**Key finding 10.** What cannot be delegated to agents in 2026: market validation, customer relationship judgment, strategic pricing, founder reputation building, "calls that require genuine skin in the game." [Mean CEO, 6.60 | Level 7]

### T3. Human-in-the-loop boundaries

**Key finding 11.** Air Canada (Feb 2024): bereavement-fare chatbot invented a refund policy; customer sued and won; defense that "chatbot was a separate legal entity" rejected. Cursor (April 2025): support bot named "Sam" fabricated a no-multi-device login policy; mass cancellations followed. [Help Scout Cursor/Air Canada synthesis, 7.20 | Level 7]

**Key finding 12.** Trust asymmetry: customers cannot verify what the agent says. "First filter" framing is misleading — for customers, the AI's response is often the entire interaction with the company. [Help Scout, 7.20 | Level 7]

**Key finding 13.** Human-Led AI Marketing operating model: "humans retain ownership of strategy, creative judgment, and final decisions, while AI accelerates research, production, execution, and optimization." Three layers — strategy / creative / execution — with human approval gates at each. [Gutenberg, 5.55 | Level 7]

**Key finding 14.** "Creativity depends on context. AI can assist, but humans must remain accountable for meaning and taste." [Gutenberg, 5.55 | Level 7]

### T4. When to add humans (team-structure transitions)

**Key finding 15.** First human hire is typically NOT an "agent manager" but someone who owns Tier 2-3 work — strategy, customer relationships, brand exceptions. Agent management is better framed as "build better Skills." [Synthesis across Mean CEO + Salesmotion]

**Key finding 16.** Emerging roles in 2026: Agent Supervisor, Agent QA Lead, AI Ops Manager. ~60% of new enterprise software projects this year include an agentic component, driving demand. Indies hit this later than enterprises; signal is "founder spending more time supervising agents than they save." [WebSearch summary of Salesforce and IBM AgentOps overviews]

**Key finding 17.** Two-week training budget per agent to reach reliable quality. Week-1 output is misleading; the improvement curve is nonlinear. [Mean CEO, 6.60 | Level 7; citing Aaron Sneed's "Council" implementation]

### T5. Practical tool stack

**Key finding 18.** Claude Agent SDK (renamed from Claude Code SDK on September 29, 2025) is the agent harness that powers Claude Code, generalized for non-coding work. Supports subagents by default, MCP integration, Skills, lifecycle hooks. [Anthropic Agent SDK, 7.05 | Level 7]

**Key finding 19.** Five-layer Claude stack: MCP (connectivity) → Skills (expertise) → Agent (execution) → Subagents (parallelism) → Agent Teams (cross-agent collaboration — experimental). Agent and subagent file format is identical (YAML frontmatter + Markdown in `.claude/agents/`); role is determined at runtime by who invokes the file. [AntStack field guide, 7.15 | Level 7]

**Key finding 20.** Framework comparison: LangGraph has highest production readiness (LangSmith, checkpointing, streaming); CrewAI best for role-based teams; AutoGen "effectively in maintenance mode." Frameworks are not interchangeable; choose based on the operational model your problem requires. [Anubhav framework comparison, 6.40 | Level 7]

**Key finding 21.** Memory infrastructure: 21 framework integrations and 20 vector stores in the Mem0 ecosystem as of early 2026. Four-scope memory model (user_id / agent_id / run_id / app_id). Procedural memory ("how things should be done") is the under-supported third type after episodic and semantic. [Mem0 State of Agent Memory, 6.95 | Level 5]

**Key finding 22.** Three benchmark standards now define memory measurement: LoCoMo (1,540 questions), LongMemEval (500 questions), BEAM (1M and 10M token scales). Token efficiency matters: a system at 26K tokens per query "is not production-viable." [Mem0, 6.95 | Level 5]

### T6. Anti-patterns and failure modes

**Key finding 23.** FTC final rule (effective October 21, 2024) prohibits fake or AI-generated consumer reviews and testimonials; fake indicators of social-media influence (bots, fake accounts); undisclosed insider reviews. Penalties up to $51,744 per violation. Air Canada precedent: companies are liable for what their AI says. [Sidley summary of FTC final rule, 8.25 | Level 4]

**Key finding 24.** Google's May 2025 guidance on scaled content abuse: "Using generative AI tools to create many pages without adding value for users may violate our spam policy." Sites with pure AI content lost 17% of traffic / 8 positions on average; sites with AI + human oversight lost only 6% / 3 positions. [SEO synthesis, 6.55 | Level 5]

**Key finding 25.** Reddit's 90/10 rule: 90% of activity must be genuine value, 10% promotional. Shadowbans in 2026 are primarily automated; triggers include rapid posting, link patterns, account-age vs. activity mismatch, IP association. AI-assisted Reddit promotion at scale is structurally fragile. [ReplyAgent Reddit rules, 5.75 | Level 7]

**Key finding 26.** Brand voice drift: AI "gradually shifts your voice toward the internet average." 68% of consumers will abandon a brand whose tone changes noticeably. Drift happens both within a single long output and across sessions. Three-layer validation (AI voice classifier + rules + human editor) catches >90% of drift with proper training. [Gutenberg + brand-voice synthesis from search summary]

### T7. Cost structure

**Key finding 27.** Cost-per-developer / per-workflow distribution (30-team audit): p10 $80, p25 $220, p50 $480, p75 $980, p90 $1,650, p99 $4,200+/month. The 20-50× spread is dominated by discipline, not usage volume. [LeanOps agentic cost runaway, 6.85 | Level 5]

**Key finding 28.** 62% of agent bills go to re-sent context (each step in an agent loop sends accumulated history). This is the single biggest optimization target. AI agents cost 10-100× more than chatbots for the same task. [LeanOps, 6.85 | Level 5]

**Key finding 29.** Four cost levers consistently cut spend 50-70% within two weeks: prompt caching (88% savings on system prompt cost across a 50-step loop), model tier routing (Haiku 80% / Sonnet 15% / Opus 5% saves 60-80%), aggressive context pruning, hard per-user budget caps. [LeanOps, 6.85 | Level 5]

**Key finding 30.** Real-world case study: 35-engineer SaaS company April 2026 bill $87K → May 2026 bill $24K after applying the four levers. Annual savings: $756K. Engineering productivity unchanged. [LeanOps, 6.85 | Level 5]

---

## 6. Methodology

### Research Design

**Research questions:**
1. **Primary:** How should a solo indie developer structure agent teams to take consumer products to market with minimal human intervention — achieving roughly 30× leverage on GTM effort?
2. **Secondary:** (a) Which GTM functions are mature for agentic execution in 2025-2026? (b) Which multi-agent architecture pattern fits a solo indie context? (c) Where do human-in-the-loop boundaries sit empirically? (d) What tool stack composes with Noah's existing infrastructure? (e) What does a realistic monthly cost look like?

**Scope boundaries:**

- In scope: multi-agent orchestration patterns 2024-2026 (2025-2026 weighted); GTM-specific agent applications; indie / solo-founder context; failure modes and guardrails; Claude-native tooling; cost modeling.
- Out of scope: enterprise multi-agent deployments; voice/IVR; coding-agent / SWE-bench work; vertical-specific GTM (healthcare, regulated finance, B2B enterprise); greenfield framework design.

**Target audience:** Noah Goodrich — solo indie developer, ADHD-typed, technical reader.

**Methodology version:** deep-research v0.1.0 (commit 84c36b0; the 8-gate compliance release with Phase 3.5 citation verification).

### Source Discovery

**Search strategy.** 21 search queries executed via WebSearch on 2026-05-23, across domains: web search, arxiv.org, vendor blogs, indie hacker forums, FTC primary sources, legal-summary blogs. Source diversity targets: Academic, Institutional, Practitioner, Boots-on-the-ground, Contrarian.

**Search log:**

| # | Query | Results found | Sources pulled for evaluation |
|---|-------|---------------|------------------------------|
| 1 | Anthropic multi-agent research system orchestrator subagent architecture 2025 | 10 | 1 (Anthropic blog) |
| 2 | Anthropic Claude Code subagents skills agent SDK 2025 2026 | 10 | 2 (Claude Agent SDK blog, AntStack guide) |
| 3 | CrewAI LangGraph AutoGen comparison production multi-agent 2026 | 9 | 1 (Medium Anubhav comparison) |
| 4 | multi-agent LLM systems contrarian fails Cognition single agent thread 2025 | 7 | 2 (Cognition essay, Cemri MASFT paper) |
| 5 | indie hacker AI agent marketing automation SEO content team case study 2025 | 9 | 0 (signals only) |
| 6 | AI agent customer support failure Air Canada Cursor hallucination 2024 2025 | 6 | 1 (Help Scout synthesis) |
| 7 | agentic outbound SDR Clay 11x Artisan Regie performance review honest | 8 | 1 (Salesmotion AI SDR comparison) |
| 8 | AI agent cost monthly API tokens production GTM workflow real numbers 2026 | 10 | 1 (LeanOps cost audit) |
| 9 | human in the loop AI agent boundaries when humans must stay GTM marketing | 8 | 1 (Gutenberg human-led AI marketing) |
| 10 | AI generated content slop SEO Google update penalty 2025 indie hacker | 10 | 1 (Google scaled content abuse synthesis) |
| 11 | MCP Model Context Protocol memory agent Mem0 Letta Cairn 2025 2026 | 10 | 1 (Mem0 State of Agent Memory) |
| 12 | Reddit Discord AI bot community management failure ban moderator backlash | 0 | 0 (no results) |
| 13 | brand voice drift AI generated content tone consistency style guide enforcement | 10 | 0 (signals only; folded into Gutenberg card and analysis §4.8) |
| 14 | Lindy Sierra Decagon Relevance AI no-code agent platform comparison 2026 | 10 | 0 (signals only) |
| 15 | "AI agent" Reddit promotion shadow ban karma posting community guidelines | 7 | 1 (ReplyAgent Reddit rules) |
| 16 | solo founder AI agent stack actually used hacker news 2025 honest review | 10 | 1 (Mean CEO solo founder stack) |
| 17 | "agent ops" "AI ops manager" emerging role 2026 oversee LLM agents | 10 | 0 (signals only; folded into analysis §4.10) |
| 18 | multi-agent LLM survey 2025 arxiv collaboration architecture taxonomy | 7 | 1 (Tran et al. MAS collaboration survey) |
| 19 | FTC AI generated reviews testimonials endorsement guides marketing compliance 2024 2025 | 10 | 1 (Sidley FTC summary) |
| 20 | cold email deliverability AI personalization warm up domain spam 2025 | 10 | 0 (signals only; folded into analysis §4.3) |
| 21 | "Why Do Multi-Agent LLM Systems Fail" Cemri 2025 14 failure modes taxonomy MAST | 9 | 0 (corroborated Cemri citation) |

**Total sources discovered:** ~170 (search results across 21 queries, ~8.5 average)
**Total sources pulled for evaluation:** 16 (full source cards completed)

### Source Evaluation

**Evaluation framework:** 10-dimension credibility rubric (see source-evaluation-rubric.md from deep-research skill commit 84c36b0)

**Evidence classification:** 9-level hierarchy (see evidence-hierarchy.md)

**Bias guards applied:**
- Per-source confirmation-bias check on every card (score harder when agreeing, gentler when disagreeing, on dimensions 5, 6, and 8)
- Triangulation rule: no claim accepted from a single source type without corroboration

**Bias-Guard Summary** *(aggregates per-card bias-guard checkboxes across all 16 cards):*

| Bias-guard outcome | Count |
|--------------------|-------|
| Agreed with source — scored harder on dims 5, 6, 8 | 10 |
| Disagreed with source — scored more generously on dims 5, 6, 8 | 2 |
| Neutral / no strong reaction | 4 |
| **Total sources evaluated** | **16** |

**Asymmetry note.** The agree-with count (10) substantially exceeds the disagree-with count (2). This is consistent with the research landscape — much of the practitioner literature on indie GTM agents leans in the same direction the researcher's priors lean (orchestrator-worker pattern is preferred; humans own strategy; brand voice as a Skill). The bias guard partially compensates (scoring those 10 sources harder on bias, logic, and honesty dimensions). Readers should weight the conclusions accordingly: where the literature consensus and the researcher prior agree, the credibility margin is narrower than the high composite scores suggest.

**Citation verification (Phase 3.5).** A 5-card random sample (30% of 16, rounded up, above the minimum-3 threshold) was selected for verification:
- T1-anthropic-multi-agent-research, T1-cognition-dont-build-multi-agents, T3-helpscout-cursor-air-canada, T5-claude-agent-sdk, T7-leanops-agent-cost-runaway.
- All 5 cards verified live; quotes match source character-for-character; attributions match bylines; location references accurate.
- **Failure rate: 0/5 = 0%** (well within the ≤5% gate).
- **IMPORTANT methodology caveat:** The skill specifies that Phase 3.5 be performed by a fresh Task-tool subagent with no shared synthesis context. This Cowork session did not have Task-tool subagent capability available, so verification was performed as self-verification by the same agent — re-checking quotes against the original `mcp__workspace__web_fetch` output, not against the card. This is a gap vs. the skill's blind-verification requirement. Re-running verification with a blind subagent is recommended before external publication. See `verification-report.md` for the full per-card outcome table.

### Inclusion / Exclusion Results

**Summary:**

| Category | Count |
|----------|-------|
| Total sources evaluated | 16 |
| Included — Core | 9 |
| Included — Supporting | 7 |
| Excluded | 0 |
| Overrides applied | 1 (T1-cognition Diversity-Include override; documented on card) |

(All 16 evaluated sources were retained; none excluded. Sources excluded from evaluation entirely — i.e., search results never card-evaluated — were dropped at the discovery stage based on the inclusion criteria pre-registered in `drafts/phase-1-design.md`.)

**Distribution by evidence level:**

| Level | Description | Count |
|-------|-------------|-------|
| 1 | Systematic review / meta-analysis | 0 |
| 2 | RCT | 0 |
| 3 | Large-scale observational | 2 (Cemri MASFT, Tran et al. MAS survey) |
| 4 | Expert consensus / professional body | 1 (Sidley FTC summary) |
| 5 | Practitioner case study | 4 (Anthropic multi-agent, Mem0, LeanOps, Google-slop synthesis) |
| 6 | Qualitative research | 0 |
| 7 | Expert opinion / thought leadership | 9 |
| 8 | Anecdotal / personal experience | 0 |
| 9 | Marketing / promotional | 0 |

**Distribution by source category:**

| Category | Included | Excluded |
|----------|----------|----------|
| Academic | 2 | 0 |
| Institutional | 4 | 0 |
| Practitioner | 8 | 0 |
| Boots-on-the-ground | 1 | 0 |
| Contrarian | 1 | 0 |

**Distribution by credibility score:**

| Score range | Count | Disposition |
|-------------|-------|-------------|
| 7.0 – 10.0 | 5 | 5 included, 0 excluded |
| 5.0 – 6.9 | 11 | 11 included, 0 excluded |
| 3.0 – 4.9 | 0 | 0 |
| 0.0 – 2.9 | 0 | 0 |

### Perspective Balance

| Topic area | Academic | Institutional | Practitioner | Boots | Contrarian |
|------------|----------|---------------|--------------|-------|------------|
| T1 architecture | Y (Cemri, Tran et al.) | Y (Anthropic) | Y (AntStack — cross-applied) | N | Y (Cognition) |
| T2 GTM functions | N | N | Y (Salesmotion) | Y (Mean CEO) | N |
| T3 HITL | N | N | Y (Help Scout, Gutenberg) | N | N |
| T4 transitions | N | N | Y (Salesmotion) | Y (Mean CEO) | N |
| T5 tools | N | Y (Anthropic SDK) | Y (AntStack, Mem0, Anubhav) | N | N |
| T6 anti-patterns | N | Y (FTC, Google) | Y (ReplyAgent) | N | N |
| T7 cost | N | N | Y (LeanOps) | N | N |

**Gap analysis.** T2, T3, T6, T7 are missing Academic perspectives; T3, T5, T6, T7 are missing Contrarian perspectives; T3 and T7 are missing Boots-on-the-ground perspectives; T1, T2, T4, T7 are missing Institutional sources. Most of these gaps are **genuine absences** rather than search gaps:

- Academic literature on agentic GTM specifically (T2, T3, T6, T7) is sparse in 2025-2026. The MAS / MASFT work (T1) is the closest academic body; it transfers conceptually but not directly to GTM.
- Contrarian voices outside T1 exist but are scattered (e.g., John Barrows's "we turned SDRs into robots and now they're being replaced by robots" via Salesmotion). The T1-Cognition card is the only single-source contrarian piece in the corpus; its critique generalizes to T2/T5/T6 implicitly. Future research could explicitly seek contrarians on "AI marketing is overhyped" — they exist on X and Substack but didn't surface high enough in the searches to clear the inclusion criteria.
- Boots-on-the-ground voices for T7 cost specifically — indie hackers in r/IndieHackers and HN threads frequently post their cost numbers, but these are typically anecdotal single-data-points that wouldn't have added more than the LeanOps audit data.

The gap is documented in §6 limitations rather than backfilled.

### Limitations

- **Phase 3.5 self-verification gap.** The blind-subagent verification protocol could not be executed in this Cowork session; self-verification was used instead. See `verification-report.md` for the full methodology caveat. Re-running verification with a blind Task-tool subagent before external publication is recommended.
- **Academic-perspective sparsity.** 4 of 7 topic areas have no Academic source. This reflects a genuine 2025-2026 literature gap (peer-reviewed work specifically on agentic GTM is sparse) but does limit the rigor of the T2, T3, T6, T7 conclusions.
- **Contrarian-perspective sparsity outside T1.** The Cognition essay is the only contrarian source. Its critique generalizes implicitly but a research extension that actively sought "agentic GTM is overhyped" essays would strengthen the corpus.
- **Vendor-blog dominance in Practitioner sources.** 8 of 16 cards are Practitioner-tagged; most are tool-vendor or consulting-firm blogs (LeanOps, Salesmotion, Mem0, AntStack, Gutenberg, ReplyAgent, Help Scout). The Intent scores reflect this; the bias-guard scoring partially compensates, but vendor-blog corpora skew toward "our category is the winning category" framings.
- **Single-evaluator scoring without inter-rater reliability checks.** All scores are applied by one agent. No second-rater calibration. Cohen's Kappa is not measurable.
- **Geographic / language scope:** US/EU English-language sources only.
- **Date cap:** 2026-05-23. Frontier-AI moves fast; conclusions about "experimental" or "maintenance mode" status may have shifted within weeks of publication.
- **One paywalled candidate not procured:** the Medium Anubhav framework-comparison piece is member-only. The public lead + WebSearch summary were used; the full article body was not procured. No paywalled-candidates file was needed because the deferred content was low-marginal value vs. the AntStack field guide that covers similar ground openly.

---

## 7. Bibliography

### Included — Core

**Anthropic (Hadfield, J. et al.).** "How we built our multi-agent research system." Anthropic Engineering Blog. June 13, 2025.
https://www.anthropic.com/engineering/multi-agent-research-system
*Score: 7.95 | Level 5 | Core.*
First-party operational account of Anthropic's Claude Research feature; the canonical reference for orchestrator-worker pattern with quantified eval gains.

**Yan, Walden.** "Don't Build Multi-Agents." Cognition AI Blog. June 12, 2025.
https://cognition.ai/blog/dont-build-multi-agents
*Score: 6.90 | Level 7 | Core (Diversity Include override).*
The contrarian anchor for the entire research. Argues for single-threaded linear agents over multi-agent architectures; the foil to Anthropic's published pattern.

**Cemri, M. et al.** "Why Do Multi-Agent LLM Systems Fail?" arXiv:2503.13657, March 2025 (NeurIPS 2025 Datasets & Benchmarks Track).
https://arxiv.org/abs/2503.13657
*Score: 8.65 | Level 3 | Core.*
First empirically grounded taxonomy of MAS failures (MASFT). 14 failure modes in 3 categories. Provides the academic rigor backing the practitioner skepticism of multi-agent.

**Shihipar, T. (with co-editors).** "Building agents with the Claude Agent SDK." Claude Engineering Blog. September 29, 2025.
https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk
*Score: 7.05 | Level 7 | Core.*
Anthropic's product positioning + design guidance for the Claude Agent SDK. Defines the primitives Noah's stack composes.

**Patterson, Mathew.** "Air Canada's Chatbot Walked So Cursor's Chatbot Could Ruin." Help Scout Blog. July 30, 2025.
https://www.helpscout.com/blog/ai-curse-of-cursor/
*Score: 7.20 | Level 7 | Core.*
Synthesis of two canonical HITL-failure case studies (Air Canada, Cursor) with the trust-asymmetry argument that generalizes to any customer-facing GTM agent.

**Brown, C. T. et al. (Sidley Austin LLP).** "U.S. FTC's New Rule on Fake and AI-Generated Reviews and Social Media Bots." Data Matters Privacy Blog. August 30, 2024.
https://datamatters.sidley.com/2024/08/30/u-s-ftcs-new-rule-on-fake-and-ai-generated-reviews-and-social-media-bots/
*Score: 8.25 | Level 4 | Core.*
Authoritative legal summary of the FTC final rule effective October 21, 2024; defines the compliance floor for AI-driven GTM.

**Mondal, Sourav (AntStack).** "Claude Agents, Subagents, Agent Teams, Skills & MCP: A Developer's Field Guide." AntStack Blog. March 9, 2026.
https://www.antstack.com/blog/claude-agents-subagents-agent-teams-skills-and-mcp-a-developer-s-field-guide/
*Score: 7.15 | Level 7 | Core.*
The cleanest synthesis of the five-layer Claude stack (MCP / Skills / Agent / Subagents / Agent Teams) with explicit decision tree and anti-patterns. Maps directly onto Noah's existing borg/drone/nanoprobe pattern.

**Jahic, Semir (Salesmotion).** "AI SDR Tools Compared: What Actually Works for B2B Pipeline in 2026." Salesmotion Blog. February 27, 2026.
https://salesmotion.io/blog/ai-sdr-tools-compared
*Score: 6.90 | Level 7 | Core.*
Three-category taxonomy of AI SDR tools with the 11x scandal as the cautionary case study. Anchors the GTM-function delegation discussion.

**Kanani, Ravi (LeanOps).** "Agentic AI Cost Runaway: Why One Cursor User Burned $4,200 in a Weekend." LeanOps Technologies Blog. May 14, 2026.
https://leanopstech.com/blog/agentic-ai-cost-runaway-token-budget-2026/
*Score: 6.85 | Level 5 | Core.*
30-team audit with percentile cost distribution; the four-cost-lever framework that anchors the cost analysis.

### Included — Supporting

**Tran, K. et al.** "Multi-Agent Collaboration Mechanisms: A Survey of LLMs." arXiv:2501.06322, January 2025.
https://arxiv.org/abs/2501.06322
*Score: 7.75 | Level 3 | Supporting.*
Academic taxonomy of MAS collaboration mechanisms (actors / types / structures / strategies / coordination protocols). Backbone categorization for architecture analysis.

**Bonenkamp, Violetta (Mean CEO).** "The Solo Founder AI Agent Stack That Is Replacing Entire Startup Teams in 2026." Mean CEO Blog. April 23, 2026.
https://blog.mean.ceo/the-solo-founder-ai-agent-stack-that-is-replacing-entire-startup-teams/
*Score: 6.60 | Level 7 | Supporting.*
The boots-on-the-ground solo-founder perspective with the context-engineering framing and explicit ceiling on what agents cannot do.

**Mem0 Engineering Team.** "State of AI Agent Memory 2026: Benchmarks, Architectures & Production Gaps." Mem0 Blog. April 1, 2026 (updated May 19, 2026).
https://mem0.ai/blog/state-of-ai-agent-memory-2026
*Score: 6.95 | Level 5 | Supporting.*
First-party benchmark data across 10 memory approaches. The 21-framework integration matrix and the four-scope memory model are the unique contributions.

**Anubhav.** "LangGraph vs CrewAI vs AutoGen: Which Agent Framework Should You Actually Use in 2026?" Data Science Collective (Medium). March 13, 2026.
https://medium.com/data-science-collective/langgraph-vs-crewai-vs-autogen-which-agent-framework-should-you-actually-use-in-2026-b8b2c84f1229
*Score: 6.40 | Level 7 | Supporting (Diversity Include).*
The most recent explicit framework comparison flagging AutoGen's maintenance-mode status.

**Niu, Sheldon (ReplyAgent).** "Reddit Self-Promotion Rules: How to Naturally Mention Your Product Without Spam (2026)." ReplyAgent.ai Blog. October 24, 2025 (updated January 2026).
https://www.replyagent.ai/blog/reddit-self-promotion-rules-naturally-mention-product
*Score: 5.75 | Level 7 | Supporting (Diversity Include).*
Codifies Reddit's 90/10 rule and shadowban triggers. The only source specifically on community-platform compliance for AI-assisted posting.

**Multi-source synthesis (Rankability + Google Search Central + Peec AI).** "Google's stance on AI content + scaled content abuse." 2025.
https://www.rankability.com/data/does-google-penalize-ai-content/
*Score: 6.55 | Level 5 | Supporting.*
Convergent vendor-and-Google synthesis on the May 2025 scaled-content-abuse policy update and quantified traffic effects.

**Gutenberg.** "Human-Led AI Marketing in Practice: A Real-World Operating Model for 2026." The Gutenberg Blog. January 15, 2026.
https://www.thegutenberg.com/blog/human-led-ai-marketing-in-practice-a-real-world-operating-model-for-2026/
*Score: 5.55 | Level 7 | Supporting.*
Practitioner agency operating-model description for human-led AI marketing. The three-layer (strategy / creative / execution) human-ownership rule is directly implementable.

### Excluded sources

None. All 16 evaluated sources were retained (9 Core + 7 Supporting). Sources excluded at the discovery / pre-evaluation stage based on the inclusion criteria pre-registered in Phase 1 are not individually enumerated here; they are summarized in §6 Methodology / Source Discovery.
