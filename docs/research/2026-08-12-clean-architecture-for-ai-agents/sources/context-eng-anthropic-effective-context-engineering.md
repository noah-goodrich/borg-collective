# Source: Effective Context Engineering for AI Agents

**Full citation:** Rajasekaran, Prithvi; Dixon, Ethan; Ryan, Carly; Hadfield, Jeremy (Anthropic Applied AI team).
"Effective context engineering for AI agents." Anthropic Engineering Blog. September 29, 2025.
**URL:** https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
**Date accessed:** 2026-08-12
**Evidence level:** 7 (Expert Opinion/Thought Leadership, with first-party production examples — Claude Code's
compaction algorithm and a Pokémon-playing agent case — but no controlled experiment or numeric table)
**Research topic area:** Context engineering and agent navigation cost — general principles for what an
agent must load to act, which frame (but do not directly test) the Clean Architecture layering tradeoff

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 10/10 | Written by Anthropic's own Applied AI team, the organization that builds Claude Code — maximal authority for how a Claude Code-class agent actually gathers context. |
| 2 | Evidence Quality | 6/10 | Describes real production mechanisms (Claude Code's context compaction, a documented Pokémon-playing agent) but presents no controlled experiment, ablation, or quantified before/after metric. |
| 3 | Currency | 10/10 | Published Sep 2025, describes current Claude Code internals; directly engages the live 2024-2026 context-engineering discourse. |
| 4 | Intent | 8/10 | Primarily educational engineering guidance for developers building agents; secondary effect of showcasing Anthropic's own tooling, but not a sales page. |
| 5 | Bias & Objectivity | 7/10 | Vendor writing about its own product's design choices, but explicitly names tradeoffs ("of course, there's a trade-off: runtime exploration is slower") rather than one-sided boosterism. |
| 6 | Logic & Coherence | 9/10 | Tight, principle-driven argument (find the smallest set of high-signal tokens) applied consistently across sub-sections (compaction, sub-agents, memory). |
| 7 | Corroboration | 7/10 | Its "smallest set of high-signal tokens" principle is independently corroborated by the Formal Architecture Descriptors navigation-cost data and by Sourcegraph's "100K-token summary performs worse than 5K-token targeted retrieval" benchmark. |
| 8 | Intellectual Honesty | 8/10 | States the cost side of its own recommended technique (just-in-time retrieval is slower than pre-computed context) instead of only listing benefits. |
| 9 | Specificity | 6/10 | Names concrete techniques (just-in-time loading, keeping the five most recently accessed files, sub-agent isolation) but gives no hard numbers for tool-call or file-read counts. |
| 10 | Relevance | 9/10 | Directly on-topic for "how should an agent gather context efficiently," though it addresses runtime retrieval strategy generally rather than the specific Clean-Architecture-layering-vs-colocation question. |

**Score band:** keep

## Bias Guard Check
- [x] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings
- Context is a finite, degrading resource ("context rot"); the operative goal is "the smallest possible set of
  high-signal tokens that maximize the likelihood of the desired outcome," not maximal information.
- Agents should prefer "just-in-time" context: maintaining lightweight identifiers (file paths, stored queries)
  and loading data at runtime via tools, rather than pre-processing everything up front — with an explicit
  admission that this is slower than pre-computed context.
- Folder hierarchies, naming conventions, and timestamps are themselves signals the agent uses to decide what
  to load and when — i.e., codebase organization is part of the context-engineering surface, not separate from it.
- Claude Code's own compaction strategy keeps a compressed summary plus only the five most recently accessed
  files, illustrating a real production bias toward narrow, current working sets over broad pre-loading.
- Sub-agents with isolated context and specialized prompts are used to prevent a single agent's context from
  being polluted by exploration needed for an unrelated subtask.

## Verified Quote(s)
**Location reference:** "Context retrieval and agentic search" section, first paragraph on the just-in-time approach.

> Rather than pre-processing all relevant data up front, agents built with the "just in time" approach maintain
> lightweight identifiers ... and use these references to dynamically load data into context at runtime using tools.

**Location reference:** "Context retrieval and agentic search" section, fourth paragraph — corrected
2026-08-12; two full paragraphs (on reference metadata as signal, and on progressive disclosure) actually
sit between the just-in-time paragraph and this one, not "immediately following" as originally claimed.

> Of course, there's a trade-off: runtime exploration is slower than retrieving pre-computed data.

**Access status:** live

## Inclusion Decision
**Decision:** Core
**Rationale:** The single highest-authority first-party source on how Claude Code itself is engineered to gather
context; sets the vocabulary (just-in-time retrieval, signal-to-noise, compaction) that every other kept source
in this track either uses or independently reinvents.
**Redundancy check:** No other kept source has this level of first-party authority on Claude Code's actual
internals; the Formal Architecture Descriptors paper and Sourcegraph's benchmark corroborate its central claim
with independent data, but neither is written by the agent's own builder.
**Perspective category:** Institutional

---
