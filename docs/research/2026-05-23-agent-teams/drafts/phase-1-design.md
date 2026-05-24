# Phase 1: Research Design — Agent Teams for Indie GTM

*Date: 2026-05-23*
*Methodology: deep-research v0.1.0 (commit 84c36b0, with Phase 3.5 citation verification)*
*Researcher: Claude (auto-approved by Noah)*

---

## Research Questions

**Primary question.** How should a solo indie developer structure agent teams to take consumer
products to market with minimal human intervention — achieving roughly 30x leverage on
go-to-market effort?

**Secondary questions.**

1. Which GTM functions (content, community, email, lead qualification, outreach, onboarding,
   support, retention, win-back) are mature enough for agentic execution in 2025–2026, and
   which still require human ownership?
2. What multi-agent architecture pattern (single-orchestrator, hierarchical, specialist-team,
   hub-and-spoke, mesh) best fits a solo indie context — both for output quality and for
   manageable operational overhead?
3. Where do human-in-the-loop boundaries sit empirically — i.e., where has agentic GTM
   demonstrably failed, and what failure modes recur?
4. What does the practical tool stack look like (MCP, Anthropic Agent Skills/Subagents,
   Claude Code, LangGraph, CrewAI, AutoGen, Mastra, vendor platforms), and which combination
   composes with Noah's existing infrastructure (Claude Desktop/Code/Cowork, plugin system,
   Cairn-style memory, borg orchestrator)?
5. What does a realistic monthly cost look like for running a continuous agentic GTM team for
   one product at indie-scale volume?

---

## Scope Boundaries

**In scope.**

- Multi-agent orchestration patterns published or surveyed in 2024–2026, with primary
  weight on 2025–2026 practitioner literature.
- GTM-specific agent applications (marketing, sales, community, support, retention).
- Indie / solo-founder context: single human operator, limited budget, multiple products in
  flight.
- Failure modes, anti-patterns, guardrails, and HITL boundaries documented in vendor
  post-mortems, case studies, and contrarian commentary.
- Tooling that interoperates with Noah's stack: MCP servers, Claude Code subagents,
  Anthropic Skills, Anthropic Agent SDK, plugin marketplaces, and memory layers (Cairn,
  Mem0, Letta).
- Cost modeling: API spend, infra, tool subscriptions, human review time.

**Out of scope.**

- Enterprise multi-agent deployments (RPA-scale, 100+ agents, contact-center replacement) —
  the operational scaffolding doesn't transfer to a one-person company.
- Voice/speech agents and IVR — Noah's products are text-first.
- Coding agents and SWE-bench leaderboard work — that's already part of Noah's existing
  delivery loop; the research question is GTM, not dev.
- Vertical-specific GTM (healthcare, regulated finance, B2B enterprise) — Noah ships
  consumer software.
- Greenfield "build your own framework from scratch" work — the question is which existing
  framework to adopt, not how to design one.

---

## Topic Map (7 subtopics → search threads)

Each subtopic gets a minimum of 3 search queries varying factual / evaluative / contrarian /
experiential framings, with deliberate targeting of all 5 perspective categories.

### T1. Multi-agent team structures (architecture patterns)

**Question:** What organizational pattern (single orchestrator, hierarchical, specialist
team-per-domain, hub-and-spoke, mesh) produces the best leverage-per-overhead ratio for a
solo operator running agents in production?

**Search angles:**
- Anthropic multi-agent research (Agent Skills, subagents, Claude Code agents)
- OpenAI Swarm / Agents SDK
- CrewAI, AutoGen, LangGraph orchestration patterns
- Academic surveys of multi-agent LLM architectures
- Practitioner post-mortems on flat vs. hierarchical agent teams
- Contrarian: "multi-agent is mostly theater" arguments

### T2. GTM functions ready for agentic delegation

**Question:** Which specific GTM functions can be delegated to agents today with acceptable
quality, and which still require human ownership?

**Search angles:**
- Agent-built content pipelines (SEO blog, social, video scripts)
- Agentic SDR / outbound (Clay, 11x, Artisan, Regie, Apollo's AI)
- Community management agents (Reddit, Discord, X/Twitter, HN)
- Email sequence design and personalization
- Lead qualification and routing
- Onboarding agents (Intercom Fin, Ada, vendor-specific)
- Support / win-back / retention
- Practitioner case studies with metrics (not vendor claims)

### T3. Human-in-the-loop boundaries

**Question:** Where do humans have to stay involved, and where has agentic GTM
demonstrably failed?

**Search angles:**
- Cursor support incident (May 2025) and similar agent-misinforms-customer incidents
- Air Canada chatbot lawsuit (legal precedent for agent claims)
- DPD / Octopus / Klarna chatbot disclosures
- LLM hallucination in customer-facing roles — published failure analyses
- Voice / brand drift case studies
- Compliance: CAN-SPAM, GDPR, FTC endorsement guides, platform ToS (Reddit, X, LinkedIn)
- Contrarian: "agents make customer trust worse" essays

### T4. Team structure transitions (when to add humans)

**Question:** At what scale or complexity does adding agents stop adding leverage, and what
does the first human hire (manager, QA, brand steward) look like?

**Search angles:**
- Indie operator essays on agent management overhead
- Fractional CMO / fractional ops trends 2025–2026
- "Agent ops" / "AI manager" emerging roles
- Quality-degradation patterns at agent-count thresholds
- Cost-of-coordination literature applied to LLM teams

### T5. Practical tool stack

**Question:** Which production-ready tools/frameworks compose with Noah's existing
infrastructure (Claude Code, Claude Desktop, Cowork plugins, MCP, Cairn memory)?

**Search angles:**
- Anthropic Agent SDK (released 2025) — capabilities, limits, ergonomics
- Claude Code subagents and Skills as orchestration substrate
- MCP server registry and tool composition patterns
- LangGraph for orchestration of long-running workflows
- CrewAI / AutoGen for role-based teams
- Mastra (TypeScript), Pydantic AI (Python) — newer entrants
- Memory layers: Mem0, Letta, Zep, native Claude memory, Cairn-style local KGs
- Vendor-specific GTM agents (Lindy, Relevance AI, Sierra, Decagon)

### T6. Anti-patterns and failure modes

**Question:** What specific failure modes have been documented, and what guardrails are
recommended?

**Search angles:**
- Hallucinated outreach (fake customer references, fabricated personalization)
- Voice / tone drift in published content
- Spam classification and deliverability damage
- Reddit/HN community-norm violations and account bans
- Compliance violations (FTC, GDPR, CAN-SPAM, platform ToS)
- Eval-driven guardrails: AI red-teaming for GTM
- Contrarian: "the marketing slop floor is rising"

### T7. Cost structure

**Question:** What does running a continuous agentic GTM team cost per month for one
indie product?

**Search angles:**
- API pricing analyses for Claude/GPT/Gemini at 2026 rates
- Cost-per-task case studies from CrewAI, LangGraph, AutoGen users
- Vendor pricing for managed agent platforms (Lindy, Relevance AI, Clay, Apollo AI)
- Total cost of ownership including infra, observability, eval
- Practitioner cost reports from indie hackers / IndieHackers / Reddit

---

## Inclusion / Exclusion Criteria (pre-registered)

**Accepted source types:**

- Peer-reviewed papers on multi-agent systems and LLM coordination (Academic).
- Vendor research from labs (Anthropic, OpenAI, Google DeepMind, Microsoft Research)
  — recognized as Institutional with explicit caveats about commercial intent.
- Industry analyst reports (Gartner, Forrester, a16z, Sequoia) — Institutional.
- Practitioner blogs, podcasts, and conference talks from named operators with
  verifiable track records.
- Boots-on-the-ground sources: Reddit (r/AI_Agents, r/IndieHackers, r/SaaS), Hacker News
  threads, GitHub READMEs, Discord community summaries.
- Contrarian essays: explicitly skeptical of multi-agent hype, including from MAS-skeptic
  researchers and practitioners.

**Date range:** 2024-01-01 onward. 2025–2026 sources preferred. Pre-2024 only if it's a
foundational reference (e.g., the original CAMEL / AutoGen / MetaGPT papers).

**Geographic / language:** English-language. US/EU/global commercial agent ecosystems.

**Excluded:**

- Pure marketing blog posts with no methodology, no metrics, and no named author.
- "Future of work" speculation pieces with no empirical backing.
- LinkedIn thought-leadership without specific examples or numbers.
- Pre-2024 work that has been superseded by Anthropic Agent Skills (Oct 2025) or the
  current Claude Code / OpenAI Agents SDK generation.

**Override hooks (documented if used):**

- A vendor case study that scores low on Intent (5/10 or below) may still be included
  as Supporting if it's the only documented operational data for a given GTM function.
- A Reddit thread or HN comment may be included as Boots-on-the-ground if it provides
  a specific failure-mode account with sufficient detail to be verifiable, even if the
  user is pseudonymous.

---

## Target Audience

**Primary reader:** Noah — solo indie developer, ADHD-typed, shipping consumer products
(reveal, troth, ingle) and infrastructure (borg, cairn). Strong technical literacy, no
patience for marketing-speak, allergic to vendor hype. Reads at the level of a senior
engineer.

**What he needs from this document:**

1. A defensible recommendation on agent team structure he can implement this quarter.
2. A list of GTM functions he can delegate today vs. functions he should hold back on.
3. A concrete cost number for running one product's GTM at indie scale.
4. Three immediate next moves to set up a GTM team for **reveal** specifically.
5. Failure modes named so he knows what to monitor.

**Tone:** ELI10 throughout, but assume Noah is technical. Skip basic agent explainers.
Lead with tension (where things break) over consensus.

---

## Output Structure

Final deliverable at
`docs/research/2026-05-23-agent-teams/analysis.md` following the §1–§7 template:

1. §1 Recommendations
2. §2 Summary
3. §3 Framework (if a framework emerges — likely a "agent team tier" or "delegation
   readiness" model)
4. §4 Analysis
5. §5 Research
6. §6 Methodology (with search log, all four distribution tables, perspective-balance
   matrix, bias-guard summary, citation-verification report counts)
7. §7 Bibliography

Source cards at
`docs/research/2026-05-23-agent-teams/sources/<topic>-<slug>.md` — one per source.

Verification report at
`docs/research/2026-05-23-agent-teams/verification-report.md` — Phase 3.5 output.

Paywalled-candidates file at
`docs/research/2026-05-23-agent-teams/paywalled-candidates.md` if any are surfaced.

---

## Auto-Approval Note

Noah explicitly granted autonomy to auto-approve this Phase 1 design and proceed without
checkpointing. The only interrupt is the paywall-surfacing protocol: if a high-value
paywalled candidate appears in Phase 2, the work pauses to write
`paywalled-candidates.md` and return to the parent agent.

Proceeding to Phase 2.
