# Anthropic's own guidance on token efficiency, context engineering, and harness design

**Date:** 2026-09-03
**Question:** What does Anthropic itself publish about token efficiency, context engineering, and
harness design for the vendor whose model and harness (Claude Code) the user actually runs?

## Executive summary

- Anthropic's canonical framing is **"context engineering"**, not prompt engineering: treat context
  as a finite, precious resource; find the smallest set of high-signal tokens that reliably
  produces the desired behavior.
  [anthropic.com/engineering/effective-context-engineering-for-ai-agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
  (2026-ish, undated but current).
- **Prompt caching is the single biggest lever the user's own data flags.** Mechanics are precise
  and documented: up to 4 breakpoints, 5-min (default) or 1-hour TTL, cache reads cost **0.1x**
  base input price (cache writes cost **1.25x** for 5-min / **2x** for 1-hour), and ANY change to
  tools/system/messages above a breakpoint invalidates everything below it in the
  tools→system→messages hierarchy.
  [platform.claude.com/docs/en/build-with-claude/prompt-caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- **Tool Search Tool with `defer_loading`** is Anthropic's real, shipped answer to progressive tool
  disclosure — a server-side API feature (beta as of doc snapshot), not a Claude Code–only trick.
  It withholds deferred tool definitions from context, exposes a `tool_search_tool_regex` or
  `tool_search_tool_bm25` search tool, and expands only the top ~5 matches (configurable up to
  10,000) into context on demand. Anthropic states a 55k-token multi-server toolset shrinks by
  **>85%** with tool search.
  [platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool)
- **Context editing + the memory tool together measured 84% token reduction and a 39% performance
  improvement** in a 100-turn web-search eval (context editing alone: 29%). Context editing clears
  *stale tool calls/results*, not conversation text, when approaching the token limit.
  [claude.com/blog/context-management](https://claude.com/blog/context-management)
- **Subagent isolation has a real, quantified cost, not just a benefit**: Anthropic's own multi-agent
  research system post states multi-agent (orchestrator + subagents) uses **~15x** the tokens of a
  single chat turn, and that token usage alone explains **80%** of performance variance (three
  factors together explain 95%). Anthropic explicitly frames multi-agent as appropriate only when
  "result value far exceeds cost."
  [anthropic.com/engineering/multi-agent-research-system](https://www.anthropic.com/engineering/multi-agent-research-system)
- **Token-efficient tool use** (beta header `token-efficient-tools-2025-02-19`) reduced *output*
  token consumption from tool calls by up to 70% for Claude 3.7 Sonnet specifically (avg. 14% in
  early usage); Claude 4 models get this by default with no header needed, and the header is a
  no-op elsewhere. [docs.claude.com token-efficient-tool-use page](https://docs.claude.com/en/docs/agents-and-tools/tool-use/token-efficient-tool-use)

## Findings

### 1. "Effective context engineering for AI agents" — concrete recommendations

Anthropic frames context engineering as the successor discipline to prompt engineering: the
question shifts from "what words go in the prompt" to "what configuration of context (system
prompt, tools, message history, retrieved data) is most likely to produce the desired behavior at
each step of a multi-turn task."
[anthropic.com/engineering/effective-context-engineering-for-ai-agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

Concrete, actionable recommendations pulled from the post:

- **System prompts**: aim for "the smallest possible set of high-signal tokens" — avoid both
  overly brittle hardcoded logic and vague high-level guidance. Structure with XML tags or
  Markdown headers (e.g. `<background_information>`, `<instructions>`). Start minimal on capable
  models and add instructions/examples only in response to observed failure modes.
- **Tool design**: tools must be self-contained, robust to error, and unambiguous in purpose;
  keep a "minimal viable set" — "if a human engineer can't definitively say which tool should be
  used in a given situation, an AI agent can't be expected to do better."
- **Few-shot examples**: curate a small set of *diverse, canonical* examples rather than
  exhaustively enumerating edge cases — "examples are the 'pictures' worth a thousand words."
- **Compaction**: summarize conversation history as it approaches the context limit, explicitly
  preserving "architectural decisions, unresolved bugs, and implementation details." Recommends
  starting by maximizing recall in the summarizer, then tuning for precision. A cheap first
  intervention: simply clear old tool call *results* from deep message history before doing full
  summarization.
- **Structured note-taking (external memory)**: agents persist notes outside the context window
  (Claude Code's own to-do list is cited as an example; NOTES.md-style files for tracking progress
  across a long task are the generalized pattern) and pull them back into context only when needed.
- **Sub-agent architectures**: specialized subagents handle a focused piece of work in their own
  context and report back a condensed summary — Anthropic's own figure: **"1,000–2,000 tokens"**
  typical for a subagent's returned summary to the lead/orchestrator agent.
- **Overarching principle** (quoted verbatim): "the smallest set of high-signal tokens that
  maximize the likelihood of your desired outcome."

This document is corroborated by (not contradicted by) the separate, more technical
`context-management` announcement below and the `multi-agent-research-system` engineering post —
all three are consistent on the compaction/memory/subagent themes, giving cross-source agreement
within Anthropic's own corpus (not full independent verification, since all three are the same
vendor).

### 2. Prompt caching — exact mechanics

Source: [platform.claude.com/docs/en/build-with-claude/prompt-caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)

- **Breakpoints**: up to **4 cache breakpoints** per request, settable via `cache_control` on
  individual content blocks (explicit) or once at the top level (automatic — the system moves the
  breakpoint forward as the conversation grows). Breakpoints are checked in a fixed hierarchy:
  **tools → system → messages**. The system checks at most **20 blocks per breakpoint** (the
  breakpoint block itself counts as block 1 of that 20).
- **TTL**: default cache type is `"ephemeral"` with a **5-minute** TTL; a **1-hour** TTL is
  available by setting `"ttl": "1h"` inside the same `cache_control` object. TTL is measured "from
  the start of the request that writes or reads the cache entry, not from the end of its response."
  Every cache hit refreshes the TTL at no extra charge.
- **Invalidation**: changing anything at a given level invalidates that level *and everything
  downstream of it* in the tools→system→messages order. Concretely documented per-change effects:
  - Tool definition changes invalidate tools, system, AND messages caches (everything).
  - Web search toggle, citations toggle, and speed setting invalidate only the tools cache.
  - Tool choice and images invalidate tools + system caches (not messages).
  - Thinking parameters / effort setting: invalidation is **model-specific** for tools/system,
    never invalidates messages.
  - The practical takeaway for an agent harness: **anything that varies turn-to-turn above your
    stable system-prompt/tool-definition prefix (e.g. injecting a live timestamp, a growing tool
    list, or a per-turn image) will blow the cache for everything after it.**
- **Minimum cacheable size** (per-model, same across platforms): most current models
  (Sonnet 4/4.5/5, Opus 4/4.1) need **1,024 tokens** minimum; some models need **512** (the doc
  lists newer/lighter-named models at this floor); Haiku 4.5 and some Opus variants need **4,096**;
  a couple of models sit at **2,048**. Below the minimum, the request silently runs uncached with
  **no error returned** — a request that looks like it's caching may not be.
- **Pricing multipliers** (verbatim from the fetched doc):
  - 5-minute cache writes: **1.25x** base input token price.
  - 1-hour cache writes: **2x** base input token price.
  - Cache reads (hits and TTL refreshes): **0.1x** base input token price — i.e. **10%** of base
    input cost. (One family of newer models is called out at **0.025x** instead of 0.1x — flagged
    as unusual and worth re-verifying against the live pricing page before relying on it.)
  - Worked example (Opus-tier pricing in the fetched doc): base input $5/MTok → 5m write
    $6.25/MTok, 1h write $10/MTok, cache read/refresh $0.50/MTok, output $25/MTok.
  - Worked example (Sonnet-tier pricing in the fetched doc): base input $2/MTok → 5m write
    $2.50/MTok, 1h write $4/MTok, cache read $0.20/MTok, output $10/MTok.
  - **Rule of thumb documented elsewhere in the ecosystem** (not Anthropic's own wording, but
    consistent with the multipliers above): the 1-hour cache's higher write premium "is only worth
    it if you will get more than 5–7 reads" — this is arithmetic implied by the 2x-write vs
    0.1x-read multipliers, not a separate Anthropic claim; treat as inference, not a quoted
    Anthropic recommendation.
- **Usage accounting**: response `usage` breaks out `cache_creation_input_tokens`,
  `cache_read_input_tokens`, and `input_tokens` (only tokens *after* the last breakpoint) — total
  input is the sum of all three. This directly explains why a session's `input_tokens` field alone
  understates true consumption if cache fields aren't also summed — relevant to the user's own
  `token-spend.jsonl` accounting practice.
- **Pre-warming**: `max_tokens: 0` writes to cache without generating output, to eliminate
  cold-cache latency on the first real turn; incompatible with streaming, extended thinking,
  structured outputs, and certain `tool_choice` settings.

Caveat: the pricing table returned by the fetch tool includes model names ("Claude Fable 5.1",
"Claude Mythos 5.1") that do not match any model naming Anthropic has publicly used as of this
model's training cutoff. These may be internal codenames from a live, current version of
Anthropic's docs (the fetch was live, dated 2026-09-03), or an artifact of the summarizing model
used by WebFetch. **Flag: verify the exact multiplier tables and model minimums against
platform.claude.com directly before hardcoding them into tooling** — the 4x categories (breakpoint
count, TTL options, tools→system→messages hierarchy, 1.25x/2x/0.1x multipliers) are corroborated
by multiple independent secondary sources (Respan, Brandon Wie, Helicone) and should be trusted;
the exact per-newest-model minimum-token table is the part to double check.

### 3. Tool Search Tool / deferred tool loading — Anthropic's native progressive disclosure

Source: [platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool),
corroborated by [anthropic.com/engineering/advanced-tool-use](https://www.anthropic.com/engineering/advanced-tool-use)
(linked from the docs page) and GitHub issues on `defer_loading` support in the Agent SDKs.

- **Name**: "Tool Search Tool," API types `tool_search_tool_regex_20251119` and
  `tool_search_tool_bm25_20251119`. Enabled by including one of these in the `tools` array and
  setting `"defer_loading": true` on tools that should stay out of context until searched for.
- **Mechanism**: deferred tools are excluded from the system-prompt prefix entirely (so the stable
  prefix — and its prompt cache — is untouched). When Claude calls the search tool, the API
  returns `tool_reference` blocks (server-side match, up to **5 by default**, caller/model can set
  `limit` 1–10,000) and auto-expands the matched ones into full definitions inline in the
  conversation before Claude sees them.
- **Documented savings** (verbatim): "A typical multiserver setup (GitHub, Slack, Sentry, Grafana,
  and Splunk) can consume ~55k tokens in definitions before Claude does any work. Tool search
  typically reduces this by over 85 percent, loading only the 3–5 tools Claude needs for a given
  request." Also: tool-selection accuracy "degrades once you exceed 30–50 available tools" —
  tool search is framed as fixing accuracy, not just cost.
- **When to use it** (Anthropic's own threshold guidance): 10+ tools available, tool definitions
  >10k tokens, MCP aggregation of 200+ tools, or a growing tool library. Standard (non-deferred)
  tool calling is recommended when under 10 tools, every tool used every request, or tool defs
  under ~100 tokens total.
- **Limits**: max 10,000 deferred tools per request; regex pattern max 200 chars; BM25 query max
  500 chars; a deferred tool cannot also carry `cache_control` (400 error) — cache breakpoints must
  sit on non-deferred tools.
- **Claude Code / Agent SDK status** (per secondary sources, not the primary doc, since this is
  API-level): Claude Code has an internal `ENABLE_TOOL_SEARCH` setting that turns this on; as of
  the GitHub issues found, the **Python and TypeScript Agent SDKs did not yet expose `defer_loading`
  / the Tool Search Tool** to SDK consumers directly — it exists at the raw Messages API level via
  the `advanced-tool-use-2025-11-20` beta header, but SDK wrapper support was an open feature
  request. **This is the single most load-bearing "not yet available where the user actually runs
  it" gap** if the user is building on the Agent SDK rather than calling the API directly.
  [github.com/anthropics/claude-agent-sdk-python/issues/525](https://github.com/anthropics/claude-agent-sdk-python/issues/525),
  [github.com/anthropics/claude-agent-sdk-typescript/issues/124](https://github.com/anthropics/claude-agent-sdk-typescript/issues/124)
- **Cost accounting caveat**: "Tool search isn't metered as a separate server tool... the tool
  definitions that search loads into context count as input tokens like any other tool definition"
  — i.e. no separate line item, it just shows up as reduced `input_tokens`.

### 4. Context compaction / auto-compact in Claude Code

Primary-source Anthropic material on auto-compact specifically (as opposed to the general
"compaction" strategy in the context-engineering post) was not found on anthropic.com/claude.com
in this pass — the detailed trigger threshold and preserved/discarded field breakdown below comes
from **secondary, practitioner sources**, not an Anthropic-authored page, and should be flagged as
such:

- Auto-compact reportedly triggers at **~95% of the model's context window**
  [claudelog.com/faqs/what-is-claude-code-auto-compact](https://claudelog.com/faqs/what-is-claude-code-auto-compact/) —
  **unverified against a primary Anthropic source**; treat as practitioner-report tier.
- Mechanism described: Claude Code pauses the turn, runs a separate summarization pass over the
  full history, and replaces earlier turns with the summary; manual trigger via `/compact`.
  [okhlopkov.com/claude-code-compaction-explained](https://okhlopkov.com/claude-code-compaction-explained/)
- What's reportedly kept: current file states, task objectives, key decisions, constraints, recent
  tool results. What's reportedly discarded: intermediate reasoning, rejected approaches, verbose
  historical command output, repeated file reads. This aligns with (but is not identical to) the
  general "compaction" guidance in Anthropic's own context-engineering post, which specifically
  calls out preserving "architectural decisions, unresolved bugs, and implementation details."
- **Gap**: Anthropic itself has not (in this search pass) published an engineering post with the
  exact numeric threshold or a field-by-field compaction spec for Claude Code specifically — the
  context-engineering post describes the *strategy* generically (applicable to any agent built on
  Claude), not the *implementation detail* of Claude Code's own compactor. Recommend treating the
  95% figure and the preserved/discarded lists as informed community reverse-engineering, not
  vendor-confirmed fact, unless corroborated further.

### 5. Token-efficient tool use (beta feature)

Source: [docs.claude.com/en/docs/agents-and-tools/tool-use/token-efficient-tool-use](https://docs.claude.com/en/docs/agents-and-tools/tool-use/token-efficient-tool-use)
(mirrored at platform.claude.com)

- Beta header: **`token-efficient-tools-2025-02-19`**.
- Applies specifically to **Claude 3.7 Sonnet**: "reducing output token consumption by up to 70%.
  On average, early users have seen a reduction of 14%."
- **Claude 4 models support this by default** — no header needed, and the header is documented as
  having "no effect on other Claude models" (i.e. it's a 3.7-Sonnet-specific opt-in that's since
  been made a first-class default behavior in later model generations).
- Available on the Anthropic API, Amazon Bedrock, and Vertex AI.
- Limitation: incompatible with `disable_parallel_tool_use`.
- This is an **output-token** savings mechanism (reduces verbosity of the tool-call payload
  itself), distinct from prompt caching (input-token reuse) and tool search (which tool
  definitions load) — three separate, stackable levers.

### 6. Subagent context isolation — Anthropic's own trade-off numbers

Source: [anthropic.com/engineering/multi-agent-research-system](https://www.anthropic.com/engineering/multi-agent-research-system)

- Architecture: orchestrator-worker pattern — a Lead Researcher agent spins up subagents that each
  explore a piece of the query in an isolated context window, then return condensed findings.
- **Explicit cost quoted**: "Multi-agent systems use about 15× more tokens than chats," and
  separately, single (non-multi-agent) "agents typically use about 4× more tokens than chat
  interactions" — establishing a rough progressive cost ladder: chat < single-agent (~4x) <
  multi-agent (~15x).
- **Performance-variance decomposition**: three factors — token usage, number of tool calls, and
  model choice — explain **95%** of variance in performance on the BrowseComp evaluation, and
  "token usage by itself explains 80% of the variance." This is Anthropic's own empirical
  justification for spending more tokens via parallel subagents: it correlates strongly with
  quality on the evaluated task, not just cost overhead.
  In the same post, a comparative claim: "upgrading to Claude Sonnet 4 is a larger performance gain
  than doubling the token budget on Claude Sonnet 3.7" — i.e. model quality beats brute-force
  token/context scaling, an important qualifier against the "just spend more tokens" reading of the
  80%-variance figure.
  A system pairing Opus 4 (lead) with Sonnet 4 (subagents) reportedly outperformed a single-agent
  setup by more than 90% on an internal evaluation (cited via secondary summaries of the same post;
  treat the exact "90%" figure as needing direct re-confirmation from the primary post text, which
  the fetch used here paraphrased rather than quoted verbatim).
- **When to use multi-agent at all**: Anthropic's own guidance (title of a related post,
  ["When to use multi-agent systems (and when not to)"](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them))
  frames multi-agent/subagent fan-out as appropriate specifically when subtasks are independent,
  the question is broad, and "the answer is worth a lot of tokens" — i.e. this is a deliberate
  cost/value trade Anthropic recommends making consciously, not a free lunch. Context isolation
  itself is "most effective when subtasks generate high context volume (>1000 tokens) but most of
  that information is irrelevant to the main task" — i.e. isolation earns its 15x tax specifically
  by discarding noisy intermediate context, not by doing more total useful work per token.
- **Directly answers the brief's question** ("what is the measured trade-off of subagents
  re-reading their own context"): Anthropic does not describe subagents as literally re-reading the
  *same* context as the orchestrator; rather each subagent pays for its own system prompt / tool
  definitions / retrieved context from scratch, and that duplication (times N subagents, plus the
  orchestrator's own overhead) is the arithmetic behind the ~15x multiplier. The orchestrator's own
  context stays lean (only receiving condensed 1,000–2,000-token summaries back per the
  context-engineering post), but the aggregate system-wide token bill is what balloons.

### 7. Memory tool / files-as-context

Source: [claude.com/blog/context-management](https://claude.com/blog/context-management) (news
post, redirected from anthropic.com/news/context-management) and
[platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool)

- **Memory tool**: a file-based system letting Claude create/read/update/delete files in a
  dedicated memory directory that persists *across* conversations (not just within one long
  session) — implementation of the storage backend is client-side (developer-managed); Anthropic
  ships SDK helper base classes `BetaAbstractMemoryTool` (Python) and `betaMemoryTool`
  (TypeScript) to subclass.
- **Context editing**: a separate, complementary feature that "automatically clears stale tool
  calls and results from within the context window" as token limits approach — this is the
  API-level analog to what the context-engineering post calls the "low-effort technique" of
  clearing old tool results from history.
- **Measured numbers** (100-turn web-search evaluation, Anthropic's own benchmark): context editing
  alone → **29%** performance improvement over baseline; context editing **+** memory tool
  combined → **39%** improvement; the combined approach also achieved an **84%** reduction in token
  consumption versus baseline, "while enabling task completion that would otherwise fail due to
  context exhaustion." This is the strongest, most concrete "write results to files instead of
  context" evidence found — a directly vendor-measured, non-marginal effect.
- **Claude Sonnet 4.5** specifically ships built-in context awareness that tracks remaining
  available tokens through a conversation, per the same post — relevant context for anything
  making assumptions about a model's own budget-awareness.
- Availability: public beta on the Claude Developer Platform, Amazon Bedrock, and Google Cloud
  Vertex AI at time of that post.

## Evidence gaps and uncertainties

- **Auto-compact's exact trigger threshold (~95%) and preserved/discarded field list is NOT sourced
  to an Anthropic-authored document** in this research pass — only practitioner blogs (ClaudeLog,
  okhlopkov.com, howaiworks.ai). Anthropic's own context-engineering post describes compaction as a
  general strategy, not Claude Code's specific implementation with numeric thresholds. Treat the
  95% figure as unconfirmed by the vendor.
- **The exact prompt-caching minimum-token-count table**, and the "0.025x cache read" outlier for
  one model family, came from a single WebFetch summarization pass over the live docs page; the
  broader structure (4 breakpoints, 5m/1h TTL, 1.25x/2x/0.1x multipliers, tools→system→messages
  invalidation order) is corroborated by multiple independent secondary sources, but the granular
  per-model minimum table should be re-verified directly against
  platform.claude.com/docs/en/build-with-claude/prompt-caching before being hardcoded anywhere.
- **Model names encountered ("Claude Fable 5.1," "Claude Mythos 5.1," "Claude Opus 5," "Claude
  Sonnet 5")** appear across multiple fetched pages (prompt-caching doc and tool-search-tool doc)
  consistently enough to suggest they reflect the live, current (2026-09-03) Anthropic docs rather
  than a hallucination — but this cannot be independently cross-checked against this assistant's
  training data, which predates these names. Flag for the user: if these look wrong relative to
  what's actually shipping, re-verify directly rather than trusting this pass.
- **Whether Claude Code (the CLI harness itself, not just the Agent SDK) natively exposes
  `defer_loading`/Tool Search Tool to end users today** is unclear — GitHub issues indicate SDK-level
  support was still an open feature request at time of search, while a separate reference to an
  `ENABLE_TOOL_SEARCH` setting suggests some native support may already exist in Claude Code
  specifically. This is directly relevant to the user (a Claude Code user) and could not be fully
  resolved — recommend checking `claude --help` / release notes or code.claude.com/docs directly.
- **The "90% outperformance" figure for the Opus-4-lead/Sonnet-4-subagent multi-agent system** was
  relayed via secondary summarization of the primary post rather than a verbatim quote pulled
  directly — the "15x tokens" and "80% variance" figures WERE captured with higher confidence
  (present in both the direct fetch and cross-referenced by community write-ups of the same post).

## Paywalled must-reads

None identified — all primary Anthropic sources on this topic are freely published engineering
blog posts and API documentation.

## Sources index

| # | Title | URL | Date | Tier |
|---|-------|-----|------|------|
| 1 | Effective context engineering for AI agents | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents | 2026 (undated, current) | [2024-2026] |
| 2 | Prompt caching (Claude Platform Docs) | https://platform.claude.com/docs/en/build-with-claude/prompt-caching | current (fetched 2026-09-03) | [2024-2026] |
| 3 | Managing context / Context management (Claude blog) | https://claude.com/blog/context-management | current | [2024-2026] |
| 4 | Tool search tool (Claude Platform Docs) | https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool | current (references 2025-11-19 tool versions) | [2024-2026] |
| 5 | Advanced tool use (Anthropic engineering) | https://www.anthropic.com/engineering/advanced-tool-use | current | [2024-2026] |
| 6 | Token-efficient tool use (Claude Docs) | https://docs.claude.com/en/docs/agents-and-tools/tool-use/token-efficient-tool-use | references Claude 3.7 Sonnet beta, 2025-02-19 | [2024-2026] |
| 7 | How we built our multi-agent research system | https://www.anthropic.com/engineering/multi-agent-research-system | 2025 | [2024-2026] |
| 8 | When to use multi-agent systems (and when not to) | https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them | current | [2024-2026] |
| 9 | Memory tool (Claude Platform Docs) | https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool | current | [2024-2026] |
| 10 | [FEATURE] Support for Tool Search Tool / defer_loading — claude-agent-sdk-python#525 | https://github.com/anthropics/claude-agent-sdk-python/issues/525 | 2026 | [2024-2026] Practitioner/GitHub |
| 11 | [FEATURE] Tool Search Tool support — claude-agent-sdk-typescript#124 | https://github.com/anthropics/claude-agent-sdk-typescript/issues/124 | 2026 | [2024-2026] Practitioner/GitHub |
| 12 | What is Claude Code auto-compact (ClaudeLog) | https://claudelog.com/faqs/what-is-claude-code-auto-compact/ | current | [2024-2026] Practitioner (unverified vs. Anthropic primary) |
| 13 | Claude Code /compact: What It Does, What Survives | https://okhlopkov.com/claude-code-compaction-explained/ | current | [2024-2026] Practitioner |
| 14 | Claude Prompt Caching Pricing: 5-Min vs 1-Hour Cache (2026) — Respan | https://www.respan.ai/articles/claude-prompt-caching | 2026 | [2024-2026] Practitioner (corroboration only) |
| 15 | Anthropic Prompt Cache TTL + Cost Mechanics — Brandon Wie | https://brandonwie.dev/posts/anthropic-prompt-cache-ttl | current | [2024-2026] Practitioner (corroboration only) |
