# Compaction and the Cost of Long Context (Habit #3)

**Date:** 2026-09-03
**Question:** Context compaction implementations, empirical evidence for "context rot" / long-context
quality degradation, the prompt-cache-invalidation cost of compaction, prefix stability as a design
goal, and file-based alternatives to compaction (scratchpads, handover docs, checkpoints).

## Executive summary

- Every frontier model tested degrades on retrieval/reasoning tasks well before hitting its context
  limit — Chroma's Context Rot study found accuracy declines starting far short of the stated window,
  and NoLiMa showed some models drop by roughly half their short-context baseline by 32K tokens.
  [trychroma.com/research/context-rot](https://www.trychroma.com/research/context-rot),
  [NoLiMa (arXiv 2502.05167)](https://arxiv.org/html/2502.05167v1)
- Compaction is not free: Anthropic's own cookbook documents that clearing/compacting **invalidates
  the cached prefix**, forcing a cache-write on the next turn — a direct admission from the vendor
  whose caching this breaks.
  [Claude Cookbook: context engineering](https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools)
- Independent research quantifies the paradox: because each LLM-generated summary is unique, it
  cannot reuse a cached prefix, so summarization API calls can eat up to ~7.2% of total instance
  cost, and once that cost is netted out, LLM summarization's efficiency edge over a much simpler
  strategy (just masking/dropping old tool outputs) "largely disappears."
  [The Complexity Trap (arXiv 2508.21433)](https://arxiv.org/pdf/2508.21433)
- Anthropic's compaction is lossy in a specific, measurable pattern: high-level facts central to the
  task tend to survive; obscure specifics (an appendix table cell, a heterogeneity statistic) tend to
  be dropped. This is a quality cost distinct from the cache-cost issue.
  [Claude Cookbook](https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools)
- File-based state (scratchpads, handover/checkpoint docs) is the alternative practitioners converge
  on precisely because it sidesteps both problems: it doesn't touch the cached prefix and it isn't
  lossy — the agent re-reads exactly what it wrote. This matches borg-collective's own existing
  design (`.borg/checkpoints/`), which the evidence below supports rather than contradicts.

## Findings

### 1. Context compaction implementations

**Claude Code (`/compact`, auto-compact).** Claude Code triggers compaction automatically near the
context ceiling (roughly 90-95% of the window budget), asks the model to generate a condensed
narrative of the whole conversation, discards the raw history, and replaces it with the summary as a
single synthetic turn at the start of a fresh context. Manual `/compact` accepts an instruction
argument to bias what's retained, and `/rewind` supports "Summarize from/up to here" for partial
compaction. [Claude Code docs: context window](https://code.claude.com/docs/en/context-window),
[ClaudeLog FAQ](https://claudelog.com/faqs/what-is-claude-code-auto-compact/) — `[2024-2026]`

**Anthropic's server-side compaction API (`compact_20260112`).** Exposed directly in the Messages
API as a `context_management` edit: set a token `trigger`, an optional custom `instructions` prompt
(which fully replaces, not supplements, the default summarization prompt), and the server returns a
typed `compaction` content block that threads tool-use pairing across the summary boundary. Default
instructions explicitly ask the model to preserve "state, next steps, learnings" for continuity — an
admission that the summary is deliberately a lossy compression optimized for task continuation, not a
faithful transcript. [Claude Cookbook](https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools)
— `[2026]`

**LangGraph/LangChain.** Two distinct primitives: `trim_messages` (produces an ephemeral trimmed copy
for a single call, doesn't touch graph state) versus `RemoveMessage` + a generated summary (edits
persisted state — messages leave the checkpoint permanently, replaced by a summary node). The
canonical pattern: keep a rolling buffer of recent messages verbatim, periodically summarize older
turns, delete the raw messages from state, and inject the summary as context on future turns.
[LangChain docs: memory](https://docs.langchain.com/oss/python/langgraph/add-memory),
[DeepWiki: message handling and summarization](https://deepwiki.com/langchain-ai/langchain-academy/5.2-message-handling-and-summarization)
— `[2024-2026]`

**Hierarchical summarization.** Traces back to the "Generative Agents" line of work: summarize
low-level events into daily summaries, daily summaries into higher-level reflections, so information
ages into progressively more compact form while recent activity stays verbatim. Framed by later
surveys as one point on a spectrum between full-append (O(n²) attention cost over a session) and
crude single-shot summarization (cheap but lossy).
[MachineLearningMastery: context window management](https://machinelearningmastery.com/context-window-management-for-long-running-agents-strategies-and-tradeoffs/) — `[2024-2026]`

**Sliding windows / observation masking.** The simplest alternative to LLM summarization: just drop
or mask old tool outputs past a horizon rather than summarizing them. The arXiv "Complexity Trap"
paper (below) is a direct head-to-head of this against LLM summarization and finds it competitive once
summarization's own cache-miss costs are counted.
[arXiv 2508.21433](https://arxiv.org/pdf/2508.21433) — `[2025]`

### 2. Context rot — degradation well within the stated window

**Chroma's "Context Rot" study** tested 18 frontier models (GPT-4.1, Claude 4, Gemini 2.5, Qwen3,
etc.) across controlled variants of needle-in-a-haystack, LongMemEval, and a repeated-words task.
Findings, with numbers:
- Performance declines as input length grows, and this decline starts well before the context limit
  — a 200K-token-window model can show meaningful degradation at 50K tokens.
  [trychroma.com/research/context-rot](https://www.trychroma.com/research/context-rot)
- Lower semantic similarity between the needle and the question accelerates degradation; adding even
  one distractor reduces accuracy versus a needle-only baseline, and four distractors compound it
  further.
- Hallucination-under-distraction rates diverged sharply by vendor: Claude models showed 0-15%
  hallucination across distractor conditions in this test; GPT models showed rates over 30%.
- On the repeated-words task (context scaled 25 → 10,000 words), accuracy on identifying a word's
  position degraded steadily with length; some models (Gemini) began generating random/incorrect
  words starting around 500-750 words; GPT-4.1 refused ~2.55% of the time past ~2,500 words; Claude
  Opus 4 on LongMemEval showed conservative *abstention* (declining to answer) driving down its
  full-113k-token-prompt accuracy relative to a focused ~300-token prompt of just the relevant
  content — i.e., the failure mode wasn't hallucination but the model correctly recognizing it
  couldn't reliably resolve the answer in the full context and refusing.
  [trychroma.com/research/context-rot](https://www.trychroma.com/research/context-rot) — `[2025]`

**NoLiMa (Adobe Research / ICML 2025)** deliberately strips literal lexical overlap between the
"needle" and the question, forcing models to use latent association rather than string matching.
Result: models that score near-perfectly (~99%) at short context lengths degrade sharply as context
grows — 10 of the tested models fell below 50% of their own short-context baseline by 32K tokens; GPT-4o
specifically dropped from 99.3% (short context) to 69.7% at longer context. The authors attribute this
to attention mechanisms struggling to link non-literal associations across a longer span — i.e.,
classic needle-in-a-haystack benchmarks *overstate* long-context ability because they let the model
exploit literal string matches. [NoLiMa paper (arXiv 2502.05167)](https://arxiv.org/html/2502.05167v1),
[HF paper page](https://huggingface.co/papers/2502.05167) — `[2025]`

**Lost in the Middle (Liu et al.)** is the foundational, earlier (pre-2024, still widely cited)
result: relevant information positioned in the middle of a long context is retrieved far less
reliably than the same information at the start or end — a U-shaped accuracy curve across position,
replicated on NaturalQuestions-Open QA and a synthetic key-value retrieval task, and since then
extended to other task types (arithmetic reasoning, multiple-choice QA, ranking). Treat as
foundational/background — it predates the current generation of long-context models and the newer
studies (Chroma, NoLiMa) are more directly relevant to today's frontier models, but it establishes the
mechanism (positional attention bias) that the newer work re-confirms and extends.
[Follow-up survey citing Liu et al.](https://arxiv.org/pdf/2412.10079) — `[pre-2024, foundational]`

### 3. The compaction trade-off — does it invalidate the cache, and is it sometimes a net loss?

**Direct vendor admission.** Anthropic's own cookbook, discussing the sibling "clearing" mechanism
in the same context-management API, states plainly: "clearing invalidates cached prompt prefixes...
you'll incur cache write costs each time clearing fires." The cookbook does not explicitly extend this
sentence to compaction, but the mechanism is structurally identical — compaction rewrites the message
history that forms the prefix, so a summary necessarily produces a new, previously-uncached prefix
requiring a fresh cache write on the next turn. This is a reasoned inference from a directly-stated
vendor fact about a sibling mechanism in the same system, not a directly-quoted claim about
compaction itself — flagged as such.
[Claude Cookbook](https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools)
— `[2026]`

**Independent quantification — the "Complexity Trap" paper.** This is the most load-bearing single
source for the "compaction can backfire" question. Findings:
- Because each LLM-generated summary is a unique sequence of turns, it cannot reuse a cached system
  prompt/prefix the way raw appended history can — "limiting cache reuse to the LLM-Summary system
  prompt."
- The summarization API calls themselves can account for up to ~7.2% of total instance cost.
- "Once summarization costs are subtracted from the total, the efficiency difference between
  LLM-Summary and Observation Masking largely disappears for most experiments" — i.e., a much
  simpler and cheaper strategy (dropping/masking old tool outputs, no LLM call) captures most of the
  benefit that LLM summarization claims credit for, once you account for what summarization itself
  costs in lost cache reuse.
[The Complexity Trap (arXiv 2508.21433)](https://arxiv.org/pdf/2508.21433) — `[2025]`

**A second practitioner data point (lower confidence, paywalled).** A Substack post ("LLM Inference
Interview Questions #7 — The Summarization Paradox") frames a scenario where a 100-step agent
trajectory expected a 5-10x cost drop from compaction/summarization but observed only ~1.3x, because
most per-step content cache-misses after a summary event. Another claim surfaced via search snippet
(not independently verified against the full paywalled text): shrinking tool output by 38.4% increased
billed cost by 6.8%, because the shrink invalidated cache hits and forced re-processing. Because the
full article is paywalled, I could not verify the exact experimental setup behind these numbers — flag
as a directionally-consistent but unverified data point, not load-bearing on its own since it echoes
(and is corroborated in direction by) the peer-reviewed-adjacent arXiv paper above.
[aiinterviewprep.substack.com](https://aiinterviewprep.substack.com/p/llm-inference-interview-questions-2d6)
— `[2025-2026, paywalled]`

**Anthropic's own compaction example shows a real net win in one case** — for a research-agent
workload, compaction fired once at 180K tokens, distilled the transcript into ~2,783 tokens, and held
peak context at 169K tokens versus 335K uncompacted (a 98% growth avoided). This does not contradict
the cache-cost finding above; it shows the trade favors compaction when the alternative is genuinely
running out of window (correctness/feasibility win), while the cache-cost literature shows compaction
can be a net *cost* loss when the alternative was merely "large but still fits, and mostly cache-hits."
The two are different regimes, and neither source frames it as one dominating the other in general.
[Claude Cookbook](https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools) — `[2026]`

**Synthesis on the trade-off:** Compaction is a tool for staying within a hard limit and for fighting
context-rot-driven quality decay, not a general-purpose cost optimization. Every compaction event is a
guaranteed one-time cache-write cost (Anthropic's own admission for the sibling clearing mechanism) and
an LLM inference cost (the summarizer call itself), which the evidence above measures at up to ~7.2%
of total run cost in one study. Compaction is worth it when (a) the run would otherwise exceed the
window, or (b) evidence (Chroma, NoLiMa) suggests context rot is already degrading quality at the
current size — not merely because context is "big."

### 4. Prefix stability as a design goal

Practitioner guidance converges on: keep everything that doesn't need to change — system prompt, tool
definitions, stable instructions — byte-identical at the front of the prompt, and push anything
volatile (tool outputs, timestamps, session-specific state) to the back, appending new messages rather
than rewriting earlier ones. Reordering, editing, or timestamp-injecting into the prefix is called out
specifically as a cache-breaking anti-pattern.
[Prompt Caching Playbook for Agentic LLMs](https://dev.to/nainikmehta/prompt-caching-playbook-for-agentic-llms-costs-latency-40nl),
[hidekazu-konishi.com: Claude prompt caching guide](https://hidekazu-konishi.com/entry/anthropic_claude_api_prompt_caching_and_token_efficiency.html)
— `[2025]`. Anthropic's stated cache economics: cached-prefix reads run at roughly a 90% discount
versus a fresh read ($0.30/M vs $3.00/M in the pricing cited), which is the concrete number that makes
prefix stability worth engineering for in the first place.
[Claude Code docs: prompt caching](https://code.claude.com/docs/en/prompt-caching) — `[2026]`

This directly informs *why* borg-collective's own architecture (per CLAUDE.md) treats things like
`--brief`'s "one sweep, one `generated_at`" and avoiding re-derivation as load-bearing: any place a
timestamp or a re-fetched value gets baked into an early-turn artifact is a potential cache-prefix
break in a Claude Code session built on that artifact.

### 5. Alternatives to compaction: scratchpads, handover docs, checkpoints

The practitioner and research consensus is that file-based external state is a first-class
alternative to compaction, not a fallback:
- "Coding agents work better when they write to disk... a markdown file is durable, greppable,
  diffable, and survives a compaction." [nikiforovall.blog: scratch](https://nikiforovall.blog/ai/2026/06/08/scratch.html)
  — `[2026]`
- Arize's framing of agent-harness context management explicitly separates "memory, files, and
  subagents" as complementary levers alongside compaction, not substitutes for one another.
  [Arize: context management in agent harnesses](https://arize.com/blog/context-management-in-agent-harnesses/)
  — `[2025-2026]`
- Anthropic's own cookbook draws the same distinction: "memory" (agent-directed writes to persistent
  storage) is lossless on whatever the agent chose to save and has no inference cost, versus
  compaction which is automatic but lossy and costs inference. Their recommended production pattern —
  which they say Claude Code itself uses — is compaction *for in-session bounding* plus memory *for
  cross-session persistence*, deployed together rather than as alternatives.
  [Claude Cookbook](https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools)
  — `[2026]`

This is a direct, independent confirmation of borg-collective's existing design choice (user-authored
`.borg/checkpoints/<ts>.md` handover files, replacing an earlier attempt at a separate knowledge-graph
service — see the Cairn decommission in this repo's CLAUDE.md) rather than something the research
contradicts. The evidence gives a mechanism-level reason *why* that design works: a checkpoint file
is exactly the "memory" side of the memory+compaction split Anthropic recommends, and it sidesteps
both known costs of compaction (cache invalidation, lossy summarization of obscure specifics) because
it's agent-authored, explicit, and read back verbatim rather than regenerated by a summarizer.

## Evidence gaps and uncertainties

- The Substack "Summarization Paradox" numbers (38.4% shrink → 6.8% cost increase; 5-10x expected vs
  1.3x observed) are behind a paywall; I could only access the free preview/teaser. I did not verify
  the underlying experimental methodology. Treat as a corroborating anecdote, not a primary number —
  the peer-reviewed-adjacent arXiv "Complexity Trap" paper is the stronger source for the same
  directional claim.
- I found no source directly measuring compaction's cache-invalidation cost with a controlled
  before/after experiment on Anthropic's actual `compact_20260112` API specifically (as opposed to the
  sibling "clearing" mechanism, or third-party/DIY summarization loops). The claim that compaction
  itself invalidates the Anthropic prompt cache is a reasoned inference from (a) Anthropic's explicit
  statement about clearing in the same system, and (b) the structural fact that a summary replaces
  the message history forming the prefix — not a directly quoted vendor statement about compaction.
- No source in this pass measured context-rot's dollar cost, only its accuracy cost. Whether
  compaction's cache-cost "loss" outweighs the accuracy-cost "gain" from fighting context rot depends
  on task economics (cost of a wrong answer vs. cost of a cache-miss), which none of the sources
  attempt to unify into one framework.
- "Context rot" numbers vary a lot by benchmark design (needle similarity, distractor count, task
  type) — Chroma's own paper stresses this variance rather than a single universal decay curve, so
  treat any single percentage (e.g., NoLiMa's "50% of baseline at 32K") as benchmark-specific, not a
  general law.

## Paywalled must-reads

- "LLM Inference Interview Questions #7 — The Summarization Paradox" —
  [aiinterviewprep.substack.com](https://aiinterviewprep.substack.com/p/llm-inference-interview-questions-2d6).
  Why it matters: appears to be the clearest single practitioner articulation of the compaction/cache
  tension with concrete before/after cost multiples, but the detailed numbers are paywalled; only the
  teaser was accessible. Access: Substack subscription.

## Sources index

| # | Title | URL | Date | Tier |
|---|-------|-----|------|------|
| 1 | Context Rot: How Increasing Input Tokens Impacts LLM Performance (Chroma) | https://www.trychroma.com/research/context-rot | 2025 | [2024-2026] |
| 2 | NoLiMa: Long-Context Evaluation Beyond Literal Matching (arXiv 2502.05167) | https://arxiv.org/html/2502.05167v1 | 2025 | [2024-2026] |
| 3 | NoLiMa paper page (Hugging Face) | https://huggingface.co/papers/2502.05167 | 2025 | [2024-2026] |
| 4 | Lost in the Middle — cited/extended in follow-up survey | https://arxiv.org/pdf/2412.10079 | pre-2024 orig., 2024 survey | [pre-2020/foundational, carried via 2024 survey] |
| 5 | Claude Cookbook: context engineering (memory, compaction, tool clearing) | https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools | 2026 | [2024-2026] |
| 6 | The Complexity Trap: Simple Observation Masking Is as Efficient as LLM Summarization (arXiv 2508.21433) | https://arxiv.org/pdf/2508.21433 | 2025 | [2024-2026] |
| 7 | LLM Inference Interview Questions #7 — The Summarization Paradox | https://aiinterviewprep.substack.com/p/llm-inference-interview-questions-2d6 | 2025-2026 | [2024-2026], paywalled |
| 8 | Prompt Caching Playbook for Agentic LLMs — Costs & Latency | https://dev.to/nainikmehta/prompt-caching-playbook-for-agentic-llms-costs-latency-40nl | 2025 | [2024-2026] |
| 9 | Anthropic Claude API Prompt Caching and Token Efficiency Guide | https://hidekazu-konishi.com/entry/anthropic_claude_api_prompt_caching_and_token_efficiency.html | 2025 | [2024-2026] |
| 10 | Claude Code docs: prompt caching | https://code.claude.com/docs/en/prompt-caching | 2026 | [2024-2026] |
| 11 | Claude Code docs: context window | https://code.claude.com/docs/en/context-window | 2026 | [2024-2026] |
| 12 | ClaudeLog FAQ: what is Claude Code auto compact | https://claudelog.com/faqs/what-is-claude-code-auto-compact/ | 2026 | [2024-2026] |
| 13 | LangChain docs: Memory (LangGraph) | https://docs.langchain.com/oss/python/langgraph/add-memory | 2025-2026 | [2024-2026] |
| 14 | DeepWiki: Message Handling and Summarization (langchain-academy) | https://deepwiki.com/langchain-ai/langchain-academy/5.2-message-handling-and-summarization | 2025 | [2024-2026] |
| 15 | MachineLearningMastery: Context Window Management for Long-Running Agents | https://machinelearningmastery.com/context-window-management-for-long-running-agents-strategies-and-tradeoffs/ | 2025-2026 | [2024-2026] |
| 16 | nikiforovall.blog: scratch — Structured Scratchpads for Coding Agents | https://nikiforovall.blog/ai/2026/06/08/scratch.html | 2026 | [2024-2026] |
| 17 | Arize AI: Context management in agent harnesses | https://arize.com/blog/context-management-in-agent-harnesses/ | 2025-2026 | [2024-2026] |
